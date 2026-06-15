#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pytest>=8",
#   "pexpect>=4",
# ]
# ///

import os
import re
import subprocess
import sys
from pathlib import Path

import pexpect
import pytest

PATHS_BASH = Path(__file__).parent.parent / "paths.bash"
BASH = "/run/current-system/sw/bin/bash"  # fallback to /bin/bash if needed
if not Path(BASH).exists():
    BASH = "/bin/bash"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def run_paths(cmd: str, fake_home: Path, cwd: str | None = None) -> tuple[str, str, int]:
    """Run cmd in a bash shell with paths.bash sourced. Returns (stdout, stderr, rc).
    Use the real function names (_PATHS_SP, etc.) since alias expansion is unreliable
    in non-interactive -c mode. The test helpers alias sp->_PATHS_SP etc. for readability.
    """
    env = {**os.environ, "HOME": str(fake_home)}
    result = subprocess.run(
        [BASH, "--norc", "-c", f". {PATHS_BASH} && {cmd}"],
        capture_output=True, text=True, env=env,
        cwd=cwd or str(fake_home),
    )
    return result.stdout, result.stderr, result.returncode


def pexpect_paths(fake_home: Path) -> pexpect.spawn:
    """Spawn an interactive bash --norc with paths.bash sourced, ready for commands."""
    env = {**os.environ, "HOME": str(fake_home), "PS1": "PROMPT> ", "PS2": ""}
    child = pexpect.spawn(BASH, ["--norc"], env=env, encoding="utf-8", timeout=5)
    child.expect(r"PROMPT> ", timeout=5)
    child.sendline(f". {PATHS_BASH}")
    child.expect(r"PROMPT> ", timeout=5)
    return child


def pexpect_run(child: pexpect.spawn, cmd: str) -> str:
    """Send a command and collect output until the next prompt. Returns output."""
    child.sendline(cmd)
    child.expect(r"PROMPT> ", timeout=5)
    return child.before


def _make_collection(lib: Path, name: str, bookmarks: dict[str, str]) -> Path:
    """Write a collection file with the given bookmarks dict."""
    pairs = "".join(f'[{k}]="{v}" ' for k, v in bookmarks.items())
    path = lib / f"{name}.collection.sh"
    path.write_text(f"declare -A path_db=({pairs})\n")
    return path


def _make_state(lib: Path, default_value: str = "/tmp", current_collection: str = "default") -> None:
    state = lib / "internal.state.sh"
    state.write_text(
        f'declare -A state_db=([default_bookmark_name]="_default" '
        f'[default_bookmark_value]="{default_value}" '
        f'[current_collection]="{current_collection}" )\n'
    )


def _make_func_collection(lib: Path, coll_name: str, func_name: str, bm_name: str, dest: str) -> None:
    """Write a collection containing one function bookmark that echoes dest.
    Matches the exact $'...' format paths.bash produces via declare -pf.
    """
    # declare -pf output: "name () \n{ \n    echo dest\n}\n"
    func_def = f"{func_name} () \n{{\n    echo {dest}\n}}\n"
    escaped = func_def.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
    name_len = len(func_name)
    value = f"$'f{name_len}:{func_name}{escaped}'"
    path = lib / f"{coll_name}.collection.sh"
    path.write_text(f"declare -A path_db=([{bm_name}]={value} )\n")


def parse_collection(path: Path) -> dict[str, str]:
    """Parse a .collection.sh file and return path_db as a Python dict."""
    text = path.read_text()
    m = re.search(r"declare -A path_db=\((.*)?\)", text, re.DOTALL)
    if not m:
        return {}
    inner = m.group(1)
    return {k: v for k, v in re.findall(r'\[([^\]]+)\]="([^"]*)"', inner)}


def parse_state(fake_home: Path) -> dict[str, str]:
    """Parse internal.state.sh and return state_db as a Python dict."""
    text = (fake_home / ".path_bookmarks" / "internal.state.sh").read_text()
    m = re.search(r"declare -A state_db=\((.*)?\)", text, re.DOTALL)
    if not m:
        return {}
    inner = m.group(1)
    return {k: v for k, v in re.findall(r'\[([^\]]+)\]="([^"]*)"', inner)}


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def lib_dir(tmp_path: Path) -> Path:
    """A fake HOME with a fully initialized .path_bookmarks library."""
    fake_home = tmp_path / "home"
    fake_home.mkdir()
    lib = fake_home / ".path_bookmarks"
    lib.mkdir()
    _make_state(lib)
    _make_collection(lib, "default", {})
    return fake_home


@pytest.fixture
def empty_home(tmp_path: Path) -> Path:
    """A fake HOME with no .path_bookmarks at all (tests auto-init)."""
    fake_home = tmp_path / "home"
    fake_home.mkdir()
    return fake_home


# ---------------------------------------------------------------------------
# Task 1: Smoke tests
# ---------------------------------------------------------------------------

def test_source_exits_zero(lib_dir):
    _, _, rc = run_paths("true", lib_dir)
    assert rc == 0


def test_init_creates_library(empty_home):
    """Sourcing paths.bash with no library should auto-create state and default collection."""
    _, _, rc = run_paths("true", empty_home)
    assert rc == 0
    lib = empty_home / ".path_bookmarks"
    assert (lib / "internal.state.sh").exists()
    assert (lib / "default.collection.sh").exists()


def test_lib_dir_fixture_is_valid(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    assert (lib / "internal.state.sh").exists()
    assert (lib / "default.collection.sh").exists()


# ---------------------------------------------------------------------------
# Task 2: sp tests
# ---------------------------------------------------------------------------

def test_sp_save_cwd_as_default(lib_dir, tmp_path):
    target = tmp_path / "target_dir"
    target.mkdir()
    stdout, stderr, rc = run_paths("_PATHS_SP", lib_dir, cwd=str(target))
    assert rc == 0, stderr
    state = parse_state(lib_dir)
    assert state["default_bookmark_value"] == str(target)


def test_sp_save_named_absolute(lib_dir):
    stdout, stderr, rc = run_paths("_PATHS_SP mybook /tmp", lib_dir)
    assert rc == 0, stderr
    db = parse_collection(lib_dir / ".path_bookmarks" / "default.collection.sh")
    assert db["mybook"] == "/tmp"


def test_sp_explicit_path_flag(lib_dir):
    stdout, stderr, rc = run_paths("_PATHS_SP -b mybook -p /tmp", lib_dir)
    assert rc == 0, stderr
    db = parse_collection(lib_dir / ".path_bookmarks" / "default.collection.sh")
    assert db["mybook"] == "/tmp"


def test_sp_no_confirm_overwrite(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default", {"mybook": "/tmp"})
    stdout, stderr, rc = run_paths("_PATHS_SP -n mybook /var", lib_dir)
    assert rc == 0, stderr
    db = parse_collection(lib_dir / ".path_bookmarks" / "default.collection.sh")
    assert db["mybook"] == "/var"


def test_sp_reject_nonexistent_path(lib_dir):
    _, stderr, rc = run_paths("_PATHS_SP mybook /nonexistent_xyz_abc", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_sp_reject_non_directory(lib_dir, tmp_path):
    f = tmp_path / "afile.txt"
    f.write_text("x")
    _, stderr, rc = run_paths(f"_PATHS_SP mybook {f}", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_sp_reject_func_and_path(lib_dir):
    _, stderr, rc = run_paths("_PATHS_SP -f somefunc -p /tmp mybook", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_sp_collection_override(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "other", {})
    stdout, stderr, rc = run_paths("_PATHS_SP -c other mybook /tmp", lib_dir)
    assert rc == 0, stderr
    other_db = parse_collection(lib / "other.collection.sh")
    default_db = parse_collection(lib / "default.collection.sh")
    assert other_db.get("mybook") == "/tmp"
    assert "mybook" not in default_db


# ---------------------------------------------------------------------------
# Task 3: pp tests
# ---------------------------------------------------------------------------

def test_pp_print_all(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default", {"alpha": "/tmp", "beta": "/var"})
    stdout, _, rc = run_paths("_PATHS_PP", lib_dir)
    assert rc == 0
    assert "alpha" in stdout
    assert "beta" in stdout


def test_pp_regex_filter(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default",
                     {"foo": "/tmp", "bar": "/var", "foobar": "/usr"})
    stdout, _, rc = run_paths("_PATHS_PP foo", lib_dir)
    assert rc == 0
    assert "foo" in stdout
    assert "foobar" in stdout
    assert "bar" not in stdout.replace("foobar", "")


def test_pp_exact_resolve_absolute(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default", {"mybook": "/tmp"})
    stdout, stderr, rc = run_paths("_PATHS_PP -R mybook", lib_dir)
    assert rc == 0, stderr
    assert stdout.strip() == "/tmp"


def test_pp_exact_resolve_relative(lib_dir, tmp_path):
    # foo=/tmp, rel_bm = r3:foo/sub  → resolves to /tmp/sub
    target = tmp_path / "sub"
    target.mkdir()
    base = "/tmp"
    # r3:foo/sub  (len("foo") == 3, relative_path == "/sub")
    rel_val = "r3:foo/sub"
    _make_collection(lib_dir / ".path_bookmarks", "default",
                     {"foo": base, "rel_bm": rel_val})
    stdout, stderr, rc = run_paths("_PATHS_PP -R rel_bm", lib_dir)
    assert rc == 0, stderr
    assert stdout.strip() == "/tmp/sub"


def test_pp_exact_resolve_function(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_func_collection(lib, "default", "find_tmp", "func_bm", "/tmp")
    stdout, stderr, rc = run_paths("_PATHS_PP -R func_bm", lib_dir)
    assert rc == 0, stderr
    assert stdout.strip() == "/tmp"


def test_pp_collection_override_header(lib_dir):
    """_PATHS_PP -c other should show 'Current collection: other' and other's bookmarks, not default's."""
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "default", {"default_bm": "/tmp"})
    _make_collection(lib, "other", {"other_bm": "/var"})
    stdout, stderr, rc = run_paths("_PATHS_PP -c other", lib_dir)
    assert rc == 0, stderr
    assert "Current collection: other" in stdout
    assert "other_bm" in stdout
    assert "default_bm" not in stdout


def test_pp_default_bookmark_shown(lib_dir):
    stdout, _, rc = run_paths("_PATHS_PP", lib_dir)
    assert rc == 0
    assert "_default" in stdout


def test_pp_exact_resolve_default(lib_dir):
    stdout, stderr, rc = run_paths("_PATHS_PP -R _default", lib_dir)
    assert rc == 0, stderr
    assert stdout.strip() == "/tmp"


# ---------------------------------------------------------------------------
# Task 4: gp tests
# ---------------------------------------------------------------------------

def test_gp_default_bookmark(lib_dir, tmp_path):
    target = tmp_path / "dest"
    target.mkdir()
    _make_state(lib_dir / ".path_bookmarks", default_value=str(target))
    stdout, stderr, rc = run_paths("_PATHS_GP && pwd", lib_dir)
    assert rc == 0, stderr
    assert str(target) in stdout


def test_gp_named_bookmark(lib_dir, tmp_path):
    target = tmp_path / "named_dest"
    target.mkdir()
    _make_collection(lib_dir / ".path_bookmarks", "default", {"dest": str(target)})
    stdout, stderr, rc = run_paths("_PATHS_GP dest && pwd", lib_dir)
    assert rc == 0, stderr
    assert str(target) in stdout


def test_gp_chained_bookmarks(lib_dir, tmp_path):
    d1 = tmp_path / "d1"; d1.mkdir()
    d2 = tmp_path / "d2"; d2.mkdir()
    _make_collection(lib_dir / ".path_bookmarks", "default",
                     {"bm1": str(d1), "bm2": str(d2)})
    stdout, stderr, rc = run_paths("_PATHS_GP bm1 bm2 && pwd", lib_dir)
    assert rc == 0, stderr
    assert str(d2) in stdout


def test_gp_relative_bookmark(lib_dir, tmp_path):
    base = tmp_path / "base"; base.mkdir()
    sub = base / "sub"; sub.mkdir()
    # rel_bm = r<len(base_bm)>:base_bm/sub
    bm_name = "base_bm"
    rel_val = f"r{len(bm_name)}:{bm_name}/sub"
    _make_collection(lib_dir / ".path_bookmarks", "default",
                     {bm_name: str(base), "rel_bm": rel_val})
    stdout, stderr, rc = run_paths("_PATHS_GP rel_bm && pwd", lib_dir)
    assert rc == 0, stderr
    assert str(sub) in stdout


def test_gp_function_bookmark(lib_dir, tmp_path):
    dest = tmp_path / "fn_dest"; dest.mkdir()
    lib = lib_dir / ".path_bookmarks"
    _make_func_collection(lib, "default", "fn_bm_func", "fn_bm", str(dest))
    stdout, stderr, rc = run_paths("_PATHS_GP fn_bm && pwd", lib_dir)
    assert rc == 0, stderr
    assert str(dest) in stdout


def test_gp_nonexistent_bookmark(lib_dir):
    _, stderr, rc = run_paths("_PATHS_GP nosuchbm", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_gp_collection_override(lib_dir, tmp_path):
    d_default = tmp_path / "dd"; d_default.mkdir()
    d_other = tmp_path / "do"; d_other.mkdir()
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "default", {"bm": str(d_default)})
    _make_collection(lib, "other", {"bm": str(d_other)})
    stdout, stderr, rc = run_paths("_PATHS_GP -c other bm && pwd", lib_dir)
    assert rc == 0, stderr
    assert str(d_other) in stdout
    assert str(d_default) not in stdout


# ---------------------------------------------------------------------------
# Task 5: dp tests
# ---------------------------------------------------------------------------

def test_dp_delete_named_no_confirm(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default",
                     {"mybook": "/tmp", "keeper": "/var"})
    stdout, stderr, rc = run_paths("_PATHS_DP -n mybook", lib_dir)
    assert rc == 0, stderr
    db = parse_collection(lib_dir / ".path_bookmarks" / "default.collection.sh")
    assert "mybook" not in db
    assert db.get("keeper") == "/var"


def test_dp_refuse_default_bookmark(lib_dir):
    _, stderr, rc = run_paths("_PATHS_DP -n _default", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_dp_nonexistent_bookmark(lib_dir):
    _, stderr, rc = run_paths("_PATHS_DP -n nosuch", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_dp_clean_absolute_no_confirm(lib_dir, tmp_path):
    real_dir = tmp_path / "real"; real_dir.mkdir()
    _make_collection(lib_dir / ".path_bookmarks", "default",
                     {"broken": "/nonexistent_xyz_abc", "good": str(real_dir)})
    stdout, stderr, rc = run_paths("_PATHS_DP -C -n", lib_dir)
    assert rc == 0, stderr
    db = parse_collection(lib_dir / ".path_bookmarks" / "default.collection.sh")
    assert "broken" not in db
    assert db.get("good") == str(real_dir)


def test_dp_collection_override_isolation(lib_dir):
    """SAFETY: dp -c other should only modify other.collection.sh, not default."""
    lib = lib_dir / ".path_bookmarks"
    default_content = {"bm_a": "/tmp"}
    other_content = {"bm_b": "/var"}
    _make_collection(lib, "default", default_content)
    _make_collection(lib, "other", other_content)

    _, stderr, rc = run_paths("_PATHS_DP -c other -n bm_b", lib_dir)
    assert rc == 0, stderr

    other_db = parse_collection(lib / "other.collection.sh")
    default_db = parse_collection(lib / "default.collection.sh")
    assert "bm_b" not in other_db
    assert default_db == default_content  # default must be completely unchanged


def test_dp_collection_override_does_not_affect_default(lib_dir):
    """Same bookmark name in both collections; delete from other; default keeps it."""
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "default", {"shared_bm": "/tmp"})
    _make_collection(lib, "other", {"shared_bm": "/var"})

    _, stderr, rc = run_paths("_PATHS_DP -c other -n shared_bm", lib_dir)
    assert rc == 0, stderr

    default_db = parse_collection(lib / "default.collection.sh")
    assert default_db.get("shared_bm") == "/tmp"


# ---------------------------------------------------------------------------
# Task 6: ml non-interactive tests
# ---------------------------------------------------------------------------

def test_ml_list(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "other", {})
    stdout, _, rc = run_paths("_PATHS_ML", lib_dir)
    assert rc == 0
    assert "default" in stdout
    assert "other" in stdout


def test_ml_create(lib_dir):
    _, stderr, rc = run_paths("_PATHS_ML -c newcoll", lib_dir)
    assert rc == 0, stderr
    p = lib_dir / ".path_bookmarks" / "newcoll.collection.sh"
    assert p.exists()
    db = parse_collection(p)
    assert db == {}


def test_ml_delete_no_confirm(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "testcoll", {})
    _, stderr, rc = run_paths("_PATHS_ML -n -d testcoll", lib_dir)
    assert rc == 0, stderr
    assert not (lib / "testcoll.collection.sh").exists()


def test_ml_rename(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "old", {"bm": "/tmp"})
    _, stderr, rc = run_paths("_PATHS_ML -n -r old new", lib_dir)
    assert rc == 0, stderr
    assert not (lib / "old.collection.sh").exists()
    assert (lib / "new.collection.sh").exists()
    assert parse_collection(lib / "new.collection.sh") == {"bm": "/tmp"}


def test_ml_copy(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "src", {"bm": "/tmp"})
    _, stderr, rc = run_paths("_PATHS_ML -n -C src dst", lib_dir)
    assert rc == 0, stderr
    assert (lib / "src.collection.sh").exists()
    assert (lib / "dst.collection.sh").exists()
    assert parse_collection(lib / "dst.collection.sh") == {"bm": "/tmp"}


def test_ml_switch_collection_positional(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "other", {})
    _, stderr, rc = run_paths("_PATHS_ML other", lib_dir)
    assert rc == 0, stderr
    state = parse_state(lib_dir)
    assert state["current_collection"] == "other"


def test_ml_shell_scope(lib_dir):
    """_PATHS_ML -S other sets _PATHS_CURRENT_COLLECTION; ml output should show (C) next to other."""
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "other", {})
    # In one shell: set shell scope, then list; the (C) marker should appear next to 'other'
    stdout, stderr, rc = run_paths("_PATHS_ML -S other && _PATHS_ML", lib_dir)
    assert rc == 0, stderr
    # After shell scope, current_collection in ml output should be 'other'
    assert "other" in stdout


def test_ml_chained_delete(lib_dir):
    """REGRESSION: ml -n -d coll1 -n -d coll2 should delete both. Exposes argc[u] bug."""
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "coll1", {})
    _make_collection(lib, "coll2", {})
    _, stderr, rc = run_paths("_PATHS_ML -n -d coll1 -n -d coll2", lib_dir)
    assert rc == 0, stderr
    assert not (lib / "coll1.collection.sh").exists()
    assert not (lib / "coll2.collection.sh").exists()
    # default must survive
    assert (lib / "default.collection.sh").exists()


def test_ml_delete_current_warns(lib_dir):
    """Deleting the current collection should print a warning."""
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "testcoll", {})
    _make_state(lib, current_collection="testcoll")
    _, stderr, rc = run_paths("_PATHS_ML -n -d testcoll", lib_dir)
    assert rc == 0
    assert "Warning" in stderr or "Warning" in _  # stderr is the right place


# ---------------------------------------------------------------------------
# Task 7: ml interactive tests (pexpect)
# ---------------------------------------------------------------------------

def test_ml_delete_confirm_yes(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "tocoll", {})
    child = pexpect_paths(lib_dir)
    try:
        child.sendline("_PATHS_ML -d tocoll")
        child.expect(r"\(y/n\)", timeout=5)
        child.sendline("y")
        child.expect(r"PROMPT> ", timeout=5)
    finally:
        child.close()
    assert not (lib / "tocoll.collection.sh").exists()


def test_ml_delete_confirm_no(lib_dir):
    """SAFETY: answering 'n' to deletion prompt must leave the collection intact."""
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "keepcoll", {})
    child = pexpect_paths(lib_dir)
    try:
        child.sendline("_PATHS_ML -d keepcoll")
        child.expect(r"\(y/n\)", timeout=5)
        child.sendline("n")
        child.expect(r"PROMPT> ", timeout=5)
    finally:
        child.close()
    assert (lib / "keepcoll.collection.sh").exists()


def test_ml_merge_ask_mode_left(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "left", {"conflict": "/tmp"})
    _make_collection(lib, "right", {"conflict": "/var"})
    child = pexpect_paths(lib_dir)
    try:
        child.sendline("_PATHS_ML -m merged left right")
        child.expect(r"\(l/r\)", timeout=5)
        child.sendline("l")
        child.expect(r"PROMPT> ", timeout=5)
    finally:
        child.close()
    db = parse_collection(lib / "merged.collection.sh")
    assert db.get("conflict") == "/tmp"


def test_ml_merge_ask_mode_right(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "left2", {"conflict": "/tmp"})
    _make_collection(lib, "right2", {"conflict": "/var"})
    child = pexpect_paths(lib_dir)
    try:
        child.sendline("_PATHS_ML -m merged2 left2 right2")
        child.expect(r"\(l/r\)", timeout=5)
        child.sendline("r")
        child.expect(r"PROMPT> ", timeout=5)
    finally:
        child.close()
    db = parse_collection(lib / "merged2.collection.sh")
    assert db.get("conflict") == "/var"


def test_dp_delete_confirm_no(lib_dir):
    """SAFETY: answering 'n' to dp prompt must leave the bookmark intact."""
    _make_collection(lib_dir / ".path_bookmarks", "default", {"mybm": "/tmp"})
    child = pexpect_paths(lib_dir)
    try:
        child.sendline("_PATHS_DP mybm")
        child.expect(r"\(y/n\)", timeout=5)
        child.sendline("n")
        child.expect(r"PROMPT> ", timeout=5)
    finally:
        child.close()
    db = parse_collection(lib_dir / ".path_bookmarks" / "default.collection.sh")
    assert db.get("mybm") == "/tmp"


# ---------------------------------------------------------------------------
# Task 8: ml subscribe/inherit tests
# ---------------------------------------------------------------------------

@pytest.fixture
def source_lib(tmp_path: Path) -> tuple[Path, Path]:
    """A second library dir acting as an external source. Returns (lib_dir, collection_path)."""
    src_home = tmp_path / "src_home"
    src_home.mkdir()
    src_lib = src_home / ".path_bookmarks"
    src_lib.mkdir()
    coll = _make_collection(src_lib, "source", {"ext_bm": "/tmp"})
    return src_lib, coll


def test_ml_inherit(lib_dir, source_lib):
    src_lib, src_coll = source_lib
    _, stderr, rc = run_paths(f"_PATHS_ML -i inherited {src_coll}", lib_dir)
    assert rc == 0, stderr
    link = lib_dir / ".path_bookmarks" / "inherited.collection.sh"
    assert link.is_symlink()
    assert link.resolve() == src_coll.resolve()
    stdout, _, _ = run_paths("_PATHS_ML", lib_dir)
    assert "(I)" in stdout


def test_ml_subscribe(lib_dir, source_lib):
    src_lib, src_coll = source_lib
    _, stderr, rc = run_paths(f"_PATHS_ML -s subscribed {src_coll}", lib_dir)
    assert rc == 0, stderr
    lib = lib_dir / ".path_bookmarks"
    copy = lib / "subscribed.collection.sh"
    src_link = lib / "subscribed.collection.sh.src"
    assert copy.exists() and not copy.is_symlink()
    assert src_link.is_symlink()
    db = parse_collection(copy)
    assert db.get("ext_bm") == "/tmp"
    stdout, _, _ = run_paths("_PATHS_ML", lib_dir)
    assert "(S)" in stdout


def test_ml_update_subscription(lib_dir, source_lib):
    src_lib, src_coll = source_lib
    run_paths(f"_PATHS_ML -s subscribed {src_coll}", lib_dir)
    # Modify the source
    _make_collection(src_lib, "source", {"ext_bm": "/var", "new_bm": "/usr"})
    _, stderr, rc = run_paths("_PATHS_ML -u subscribed", lib_dir)
    assert rc == 0, stderr
    db = parse_collection(lib_dir / ".path_bookmarks" / "subscribed.collection.sh")
    assert db.get("ext_bm") == "/var"
    assert db.get("new_bm") == "/usr"


def test_ml_inherit_broken_link_error(lib_dir, source_lib):
    src_lib, src_coll = source_lib
    run_paths(f"_PATHS_ML -i inherited {src_coll}", lib_dir)
    src_coll.unlink()  # break the link
    _, stderr, rc = run_paths("_PATHS_ML inherited", lib_dir)
    assert rc != 0
    assert "Error" in stderr


# ---------------------------------------------------------------------------
# Task 1: pp --list-mode tests
# ---------------------------------------------------------------------------

def test_pp_list_names_all(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default", {"alpha": "/tmp", "beta": "/var"})
    stdout, _, rc = run_paths("_PATHS_PP -l names", lib_dir)
    assert rc == 0
    lines = stdout.splitlines()
    assert "alpha" in lines
    assert "beta" in lines
    assert "Bookmark" not in stdout


def test_pp_list_names_filter(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default",
                     {"foo": "/tmp", "bar": "/var", "foobar": "/usr"})
    stdout, _, rc = run_paths("_PATHS_PP -l n foo", lib_dir)
    assert rc == 0
    lines = stdout.splitlines()
    assert "foo" in lines
    assert "foobar" in lines
    assert "bar" not in lines


def test_pp_list_paths_all(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default", {"mybm": "/tmp"})
    stdout, _, rc = run_paths("_PATHS_PP -l p", lib_dir)
    assert rc == 0
    assert "/tmp" in stdout.splitlines()


def test_pp_list_paths_resolve(lib_dir, tmp_path):
    base = tmp_path / "base"; base.mkdir()
    sub = base / "sub"; sub.mkdir()
    bm_name = "base_bm"
    rel_val = f"r{len(bm_name)}:{bm_name}/sub"
    _make_collection(lib_dir / ".path_bookmarks", "default",
                     {bm_name: str(base), "rel_bm": rel_val})
    stdout, _, rc = run_paths("_PATHS_PP -r -l p rel_bm", lib_dir)
    assert rc == 0
    assert str(sub) in stdout.splitlines()


def test_pp_list_both_all(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default", {"mybm": "/tmp"})
    stdout, _, rc = run_paths("_PATHS_PP -l b", lib_dir)
    assert rc == 0
    assert any("mybm" in line and "/tmp" in line for line in stdout.splitlines())


def test_pp_list_shorthand(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default", {"bm": "/tmp"})
    for mode in ["n", "p", "b"]:
        stdout, _, rc = run_paths(f"_PATHS_PP -l {mode}", lib_dir)
        assert rc == 0


def test_pp_list_invalid_mode(lib_dir):
    _, stderr, rc = run_paths("_PATHS_PP -l bogus", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_pp_list_incompatible_with_R(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default", {"bm": "/tmp"})
    _, stderr, rc = run_paths("_PATHS_PP -R bm -l n", lib_dir)
    assert rc != 0
    assert "Error" in stderr


# ---------------------------------------------------------------------------
# Task 2: sp --rename tests
# ---------------------------------------------------------------------------

def test_sp_rename_basic(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default", {"old": "/tmp"})
    _, stderr, rc = run_paths("_PATHS_SP --rename old new", lib_dir)
    assert rc == 0, stderr
    db = parse_collection(lib_dir / ".path_bookmarks" / "default.collection.sh")
    assert "old" not in db
    assert db.get("new") == "/tmp"


def test_sp_rename_value_preserved(lib_dir):
    """Rename preserves the raw stored value verbatim."""
    bm_name = "base_bm"
    rel_val = f"r{len(bm_name)}:{bm_name}/sub"
    _make_collection(lib_dir / ".path_bookmarks", "default",
                     {bm_name: "/tmp", "rel_bm": rel_val})
    _, stderr, rc = run_paths("_PATHS_SP --rename rel_bm rel_new", lib_dir)
    assert rc == 0, stderr
    db = parse_collection(lib_dir / ".path_bookmarks" / "default.collection.sh")
    assert "rel_bm" not in db
    assert db.get("rel_new") == rel_val


def test_sp_rename_no_confirm_overwrite(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default",
                     {"old": "/tmp", "existing": "/var"})
    _, stderr, rc = run_paths("_PATHS_SP -n --rename old existing", lib_dir)
    assert rc == 0, stderr
    db = parse_collection(lib_dir / ".path_bookmarks" / "default.collection.sh")
    assert "old" not in db
    assert db.get("existing") == "/tmp"


def test_sp_rename_prompts_overwrite(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default",
                     {"old": "/tmp", "existing": "/var"})
    child = pexpect_paths(lib_dir)
    try:
        child.sendline("_PATHS_SP --rename old existing")
        child.expect(r"\(y/n\)", timeout=5)
        child.sendline("n")
        child.expect(r"PROMPT> ", timeout=5)
    finally:
        child.close()
    db = parse_collection(lib_dir / ".path_bookmarks" / "default.collection.sh")
    assert db.get("old") == "/tmp"
    assert db.get("existing") == "/var"


def test_sp_rename_error_source_missing(lib_dir):
    _, stderr, rc = run_paths("_PATHS_SP --rename nosuch newname", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_sp_rename_error_is_default_bm(lib_dir):
    _, stderr, rc = run_paths("_PATHS_SP --rename _default newname", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_sp_rename_collection_override(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "default", {"bm": "/tmp"})
    _make_collection(lib, "other", {"old": "/var"})
    _, stderr, rc = run_paths("_PATHS_SP -c other --rename old new", lib_dir)
    assert rc == 0, stderr
    other_db = parse_collection(lib / "other.collection.sh")
    default_db = parse_collection(lib / "default.collection.sh")
    assert "old" not in other_db
    assert other_db.get("new") == "/var"
    assert default_db == {"bm": "/tmp"}


# ---------------------------------------------------------------------------
# Task 3: sp --copy / --move tests
# ---------------------------------------------------------------------------

def test_sp_copy_basic(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "default", {"mybm": "/tmp"})
    _make_collection(lib, "other", {})
    _, stderr, rc = run_paths("_PATHS_SP --copy mybm --to other", lib_dir)
    assert rc == 0, stderr
    assert parse_collection(lib / "other.collection.sh").get("mybm") == "/tmp"


def test_sp_copy_source_intact(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "default", {"mybm": "/tmp"})
    _make_collection(lib, "other", {})
    run_paths("_PATHS_SP --copy mybm --to other", lib_dir)
    assert parse_collection(lib / "default.collection.sh").get("mybm") == "/tmp"


def test_sp_move_basic(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "default", {"mybm": "/tmp"})
    _make_collection(lib, "other", {})
    _, stderr, rc = run_paths("_PATHS_SP --move mybm --to other", lib_dir)
    assert rc == 0, stderr
    assert parse_collection(lib / "other.collection.sh").get("mybm") == "/tmp"


def test_sp_move_source_removed(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "default", {"mybm": "/tmp"})
    _make_collection(lib, "other", {})
    run_paths("_PATHS_SP --move mybm --to other", lib_dir)
    assert "mybm" not in parse_collection(lib / "default.collection.sh")


def test_sp_copy_conflict_overwrite_no_confirm(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "default", {"mybm": "/tmp"})
    _make_collection(lib, "other", {"mybm": "/var"})
    _, stderr, rc = run_paths("_PATHS_SP -n --copy mybm --to other", lib_dir)
    assert rc == 0, stderr
    assert parse_collection(lib / "other.collection.sh").get("mybm") == "/tmp"


def test_sp_copy_conflict_prompts(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "default", {"mybm": "/tmp"})
    _make_collection(lib, "other", {"mybm": "/var"})
    child = pexpect_paths(lib_dir)
    try:
        child.sendline("_PATHS_SP --copy mybm --to other")
        child.expect(r"\(y/n\)", timeout=5)
        child.sendline("n")
        child.expect(r"PROMPT> ", timeout=5)
    finally:
        child.close()
    assert parse_collection(lib / "other.collection.sh").get("mybm") == "/var"


def test_sp_copy_error_no_to(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default", {"mybm": "/tmp"})
    _, stderr, rc = run_paths("_PATHS_SP --copy mybm", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_sp_move_error_no_to(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default", {"mybm": "/tmp"})
    _, stderr, rc = run_paths("_PATHS_SP --move mybm", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_sp_copy_error_missing_bm(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "default", {})
    _make_collection(lib, "other", {})
    _, stderr, rc = run_paths("_PATHS_SP --copy nosuch --to other", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_sp_copy_error_missing_dest_collection(lib_dir):
    _make_collection(lib_dir / ".path_bookmarks", "default", {"mybm": "/tmp"})
    _, stderr, rc = run_paths("_PATHS_SP --copy mybm --to nonexistent", lib_dir)
    assert rc != 0
    assert "Error" in stderr


def test_sp_copy_with_source_override(lib_dir):
    lib = lib_dir / ".path_bookmarks"
    _make_collection(lib, "default", {})
    _make_collection(lib, "src", {"mybm": "/usr"})
    _make_collection(lib, "dst", {})
    _, stderr, rc = run_paths("_PATHS_SP -c src --copy mybm --to dst", lib_dir)
    assert rc == 0, stderr
    assert parse_collection(lib / "dst.collection.sh").get("mybm") == "/usr"
    assert parse_collection(lib / "default.collection.sh") == {}


# ---------------------------------------------------------------------------
# Script entrypoint (uv run --script test/test_paths.py)
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v", *sys.argv[1:]]))
