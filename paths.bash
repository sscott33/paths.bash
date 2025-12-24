# MIT License
#
# Copyright (c) 2022–2025 Samuel Odell Scott.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# BEGIN USER CUSTOMIZATIONS ############################################################################################
export _PATHS_LIBRARY="$HOME/.path_bookmarks"
_PATHS_DEFAULT_BM_NAME=_default
declare -A _PATHS_FUNC_ALIASES=([_PATHS_GP]="gp" [_PATHS_SP]="sp" [_PATHS_DP]="dp" [_PATHS_PP]="pp" [_PATHS_ML]="ml")
# END USER CUSTOMIZATIONS ##############################################################################################

export _PATHS_STATE_FILE="$_PATHS_LIBRARY/internal.state.sh"

# allow for renaming the functions in case of collision; note that "complete" commands will need to be updated with new aliases
for _PATHS_FUNC in "${!_PATHS_FUNC_ALIASES[@]}"; do
    alias ${_PATHS_FUNC_ALIASES[$_PATHS_FUNC]}=$_PATHS_FUNC
done
unset _PATHS_FUNC

# init path database if it does not exist
if [[ ! -d $_PATHS_LIBRARY ]]; then
    mkdir -p "$_PATHS_LIBRARY" || echo >&2 "Error: please make sure that the directory '$_PATHS_LIBRARY' exists or can be created"
fi

# running in a subshell to protect potential user variables "state_db" and "path_db"
(
    if [[ ! -e $_PATHS_STATE_FILE ]]; then
        declare -gA state_db
        state_db=(
            [default_bookmark_name]=$_PATHS_DEFAULT_BM_NAME
            [default_bookmark_value]=$HOME
            [current_collection]=default
        )

        declare -p state_db > "$_PATHS_STATE_FILE"

        collection_name=default
        db_path=$_PATHS_LIBRARY/$collection_name.collection.sh

        if [[ ! -e $db_path ]]; then
            declare -gA path_db
            declare -p path_db > "$db_path"
        fi
    fi

    # handle case where the user is updating the default bookmark name after initialization
    . "$_PATHS_STATE_FILE"
    if [[ ${state_db[default_bookmark_name]} != "$_PATHS_DEFAULT_BM_NAME" ]]; then
        state_db[default_bookmark_name]=$_PATHS_DEFAULT_BM_NAME
        declare -p state_db > "$_PATHS_STATE_FILE"
    fi
)
unset _PATHS_DEFAULT_BM_NAME

_PATHS_LOAD_STATE () {
    if [[ ! -e $_PATHS_STATE_FILE ]]; then
        echo >&2 "Error: path state file does not exist (state file = '$_PATHS_STATE_FILE')"
        return 1
    fi
    cat "$_PATHS_STATE_FILE"
}

_PATHS_SAVE_STATE () {
    declare -p state_db > "$_PATHS_STATE_FILE"
}

_PATHS_LOAD_DB () {
    local collection_name
    local db_path

    collection_name=$1
    #collection_name=${_PATHS_STATE_DB[collection_name]}
    db_path=$_PATHS_LIBRARY/$collection_name.collection.sh

    if [[ ! -e $db_path ]]; then
        echo >&2 "Error: cannot load collection '$collection_name', it does not exist in library (collection path = '$db_path')"
        return 1
    fi

    cat "$db_path"
}

_PATHS_SAVE_DB () {
    local collection_name
    local db_path

    collection_name=$1
    #collection_name=${_PATHS_STATE_DB[collection_name]}
    db_path=$_PATHS_LIBRARY/$collection_name.collection.sh
    
    declare -p path_db > "$db_path"

    if [[ ! -v NO_WARN && ! -e $db_path ]]; then
        echo >&2 "Warning: collection '$collection_name' created in libary (db_path = '$db_path')"
    fi
}

_PATHS_KEY_COMPLETIONS() {
    # completion words come from the keys of the associative array stored in the file below
    local path_db
    local state_db
    eval "$(_PATHS_LOAD_STATE)"

    local idx
    local override
    for idx in "${!COMP_WORDS[@]}"; do
        case "${COMP_WORDS[idx]}" in
            -c|--collection) override=${COMP_WORDS[idx+1]} ;;
    esac

    done
    if [[ -n $override && -e $_PATHS_LIBRARY/$override.collection.sh ]]; then
        eval "$(_PATHS_LOAD_DB "$override")"
    else
        eval "$(_PATHS_LOAD_DB "${_PATHS_CURRENT_COLLECTION:-${state_db[current_collection]}}")"
    fi

    # get the currently completing word
    local partial_key=${COMP_WORDS[COMP_CWORD]}

    # change IFS so that the completions can contain spaces
    # using $-string to get actual newline character
    local IFS=$'\n'

    # filter through keys based on currently completing word
    # adding default bookmark to db since it doesn't exist there any more
    local default_bm_name
    local default_bm_value
    default_bookmark_name=${state_db[default_bookmark_name]}
    default_bookmark_value=${state_db[default_bookmark_value]}
    path_db[$default_bookmark_name]=$default_bookmark_value
    # store the result in an array
    # must use * instead of @ for quoting to happen correctly
    local completions=($(compgen -W "${!path_db[*]}" "$partial_key"))

    # set COMPREPLY based on the available completions
    if [[ ${#completions[@]} -eq 0 ]]; then
        # set to an empty array if there are no possible completions
        # cannot just use printf because of quoting
        COMPREPLY=()
    else
        # copy array of completions to COMPREPLY (must use printf for spaces to be valid because IFS is newline)
        # the '%q' preserves the completions in a format that can be reused as shell input & uses $-strings to handle escape chars
        COMPREPLY=($(printf -- '%q\n' "${completions[@]}"))
    fi
}

_PATHS_FUNC_COMPLETIONS () {
    # get the currently completing word
    local partial_key=${COMP_WORDS[COMP_CWORD]}

    # change IFS so that the completions can contain spaces
    # using $-string to get actual newline character
    local IFS=$'\n'

    # retrieve a list of declared functions
    declare -a functions=($(declare -F | cut -c12-))

    # filter through functions based on currently completing word
    # store the result in an array
    # must use * instead of @ for quoting to happen correctly
    local completions=($(compgen -W "${functions[*]}" "$partial_key"))

    # set COMPREPLY based on the available completions
    if [[ ${#completions[@]} -eq 0 ]]; then
        # set to an empty array if there are no possible completions
        # cannot just use printf because of quoting
        COMPREPLY=()
    else
        # copy array of completions to COMPREPLY (must use printf for spaces to be valid because IFS is newline)
        # the '%q' preserves the completions in a format that can be reused as shell input & uses $-strings to handle escape chars
        COMPREPLY=($(printf -- '%q\n' "${completions[@]}"))
    fi
}

_PATHS_COLLECTION_COMPLETIONS () {
    # get the currently completing word
    local partial_key=${COMP_WORDS[COMP_CWORD]}

    # change IFS so that the completions can contain spaces
    # using $-string to get actual newline character
    local IFS=$'\n'

    # retrieve a list of declared completions
    declare -a completions=($_PATHS_LIBRARY/*.collection.sh)
    local idx
    for idx in "${!completions[@]}"; do
        completions[idx]=${completions[idx]##*/}
        completions[idx]=${completions[idx]%.collection.sh}
    done

    # filter through completions based on currently completing word
    # store the result in an array
    # must use * instead of @ for quoting to happen correctly
    local completions=($(compgen -W "${completions[*]}" "$partial_key"))

    # set COMPREPLY based on the available completions
    if [[ ${#completions[@]} -eq 0 ]]; then
        # set to an empty array if there are no possible completions
        # cannot just use printf because of quoting
        COMPREPLY=()
    else
        # copy array of completions to COMPREPLY (must use printf for spaces to be valid because IFS is newline)
        # the '%q' preserves the completions in a format that can be reused as shell input & uses $-strings to handle escape chars
        COMPREPLY=($(printf -- '%q\n' "${completions[@]}"))
    fi
}

# add completion functionality to all functions except sp; not sure how to do completion based on argument position
_PATHS_GP_COMPLETION () {
    declare -a short_opts=(-h -b -c)
    declare -a long_opts=(--help --bookmark --collection)
    local partial_key="${COMP_WORDS[COMP_CWORD]}"

    ((COMP_CWORD >= 1)) && case "${COMP_WORDS[COMP_CWORD-1]}" in
        -b|--bookmark)
            _PATHS_KEY_COMPLETIONS
            return 0
            ;;
        -c|--collection)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
    esac

    case "${COMP_WORDS[COMP_CWORD]}" in 
        --*)
            COMPREPLY=($(compgen -W "${long_opts[*]}" -- "$partial_key"))
            return 0
            ;;
        -*)
            COMPREPLY=($(compgen -W "${short_opts[*]} ${long_opts[*]}" -- "$partial_key"))
            return 0
            ;;
        *)
            _PATHS_KEY_COMPLETIONS
            return 0
            ;;
    esac

    ## figure out how many positional args we have
    #local positional_arg_num=-1
    #local arg
    #local opt
    #declare -a opts_with_arg=(-p --path -b --bookmark -c --collection)
    #for arg in "${COMP_WORDS[@]}"; do
    #    [[ "$arg" =~ ^- ]] || ((positional_arg_num++))
    #    for opt in "${opts_with_arg[@]}"; do
    #        [[ "$arg" == "$opt" ]] && { ((positional_arg_num--)); break; }
    #    done
    #done

    ## complete the positional arguments
    #case $positional_arg_num in
    #    1)
    #        # offer existing bookmarks as options for the case of reassigning a bookmark
    #        _PATHS_KEY_COMPLETIONS
    #        ;;
    #esac
}
complete -F _PATHS_GP_COMPLETION ${_PATHS_FUNC_ALIASES[_PATHS_GP]}

_PATHS_DP_COMPLETION () {
    declare -a short_opts=(-h -ca -cf -cr -n -c)
    declare -a long_opts=(--help --clean-absolute --clean-functions --clean-relative --no-confirm --collection)
    local partial_key="${COMP_WORDS[COMP_CWORD]}"

    ((COMP_CWORD >= 1)) && case "${COMP_WORDS[COMP_CWORD-1]}" in
        -c|--collection)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
    esac

    case "${COMP_WORDS[COMP_CWORD]}" in 
        --*)
            COMPREPLY=($(compgen -W "${long_opts[*]}" -- "$partial_key"))
            ;;
        -*)
            COMPREPLY=($(compgen -W "${short_opts[*]} ${long_opts[*]}" -- "$partial_key"))
            ;;
        *)
            _PATHS_KEY_COMPLETIONS
            ;;
    esac
}
complete -F _PATHS_DP_COMPLETION ${_PATHS_FUNC_ALIASES[_PATHS_DP]}

_PATHS_PP_COMPLETION () {
    declare -a short_opts=(-h -R -r -f -c)
    declare -a long_opts=(--help --exact-resolve --resolve --function-body --collection)
    local partial_key="${COMP_WORDS[COMP_CWORD]}"

    ((COMP_CWORD >= 1)) && case "${COMP_WORDS[COMP_CWORD-1]}" in
        -c|--collection)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
    esac

    case "${COMP_WORDS[COMP_CWORD]}" in 
        --*)
            COMPREPLY=($(compgen -W "${long_opts[*]}" -- "$partial_key"))
            ;;
        -*)
            COMPREPLY=($(compgen -W "${short_opts[*]} ${long_opts[*]}" -- "$partial_key"))
            ;;
        *)
            _PATHS_KEY_COMPLETIONS
            ;;
    esac
}
complete -F _PATHS_PP_COMPLETION ${_PATHS_FUNC_ALIASES[_PATHS_PP]}

_PATHS_SP_COMPLETION () {
    declare -a short_opts=(-b -f -p -r -n -h -c)
    declare -a long_opts=(--bookmark --function --path --relative-to --no-confirm --help --collection)
    local partial_key="${COMP_WORDS[COMP_CWORD]}"

    ((COMP_CWORD >= 1)) && case "${COMP_WORDS[COMP_CWORD-1]}" in
        -c|--collection)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
        -b|--bookmark)
            _PATHS_KEY_COMPLETIONS
            return 0
            ;;
        -f|--function)
            _PATHS_FUNC_COMPLETIONS
            return 0
            ;;
        -p|--path)
            COMPREPLY=($(compgen -o dirnames -- "$partial_key"))
            return 0
            ;;
        -r|--relative-to)
            _PATHS_KEY_COMPLETIONS
            return 0
            ;;
    esac

    case "${COMP_WORDS[COMP_CWORD]}" in 
        --*)
            COMPREPLY=($(compgen -W "${long_opts[*]}" -- "$partial_key"))
            return 0
            ;;
        -*)
            COMPREPLY=($(compgen -W "${short_opts[*]} ${long_opts[*]}" -- "$partial_key"))
            return 0
            ;;
    esac

    # figure out how many positional args we have
    local positional_arg_num=-1
    local arg
    local opt
    declare -a opts_with_arg=(-p --path -b --bookmark -f --function -r --relative-to)
    for arg in "${COMP_WORDS[@]}"; do
        [[ "$arg" =~ ^- ]] || ((positional_arg_num++))
        for opt in "${opts_with_arg[@]}"; do
            [[ "$arg" == "$opt" ]] && { ((positional_arg_num--)); break; }
        done
    done

    # complete the positional arguments
    case $positional_arg_num in
        2)
            # complete directory names
            COMPREPLY=($(compgen -o dirnames -- "${COMP_WORDS[COMP_CWORD]}"))
            ;;
        1)
            # offer existing bookmarks as options for the case of reassigning a bookmark
            _PATHS_KEY_COMPLETIONS
            ;;
    esac
}
complete -F _PATHS_SP_COMPLETION ${_PATHS_FUNC_ALIASES[_PATHS_SP]}
compopt -o nospace ${_PATHS_FUNC_ALIASES[_PATHS_SP]}

_PATHS_ML_COMPLETION () {
    #set -x
    declare -a short_opts=(-l -r -d -c -C -m -M -s -i -u -S -R -n -h)
    declare -a long_opts=(--list-collections --rename-collection --delete-collection --create-collection
        --copy-collection --merge-collections --merge-mode --subscribe-to-collection --inherit-collection
        --update-subscription --shell-scope --reset-scope --no-confirm --help)

    local partial_key="${COMP_WORDS[COMP_CWORD]}"

    ((COMP_CWORD >= 3)) && case "${COMP_WORDS[COMP_CWORD-3]}" in
        -m|--merge-collections)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
    esac
    ((COMP_CWORD >= 2)) && case "${COMP_WORDS[COMP_CWORD-2]}" in
        -C|--copy-collection)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
        -s|--subscribe-to-collection)
            #echo ------0
            #set -x
            COMPREPLY=($(compgen -o default -- "$partial_key"))
            #set +x
            #echo ------0
            return 0
            ;;
        -r|--rename-collection)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
        -m|--merge-collections)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
        -i|--inherit-collection)
            #echo ------1
            #set -x
            COMPREPLY=($(compgen -o default -- "$partial_key"))
            #set +x
            #echo ------1
            return 0
            ;;
    esac
    ((COMP_CWORD >= 1)) && case "${COMP_WORDS[COMP_CWORD-1]}" in
        -C|--copy-collection)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
        -c|--create-collection)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
        -s|--subscribe-to-collection)
            #echo ------2
            #set -x
            COMPREPLY=($(compgen -o default -- "$partial_key"))
            #set +x
            #echo ------2
            return 0
            ;;
        -u|--update-subscription)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
        -d|--delete-collection)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
        -r|--rename-collection)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
        -m|--merge-collections)
            #echo ------3
            #set -x
            COMPREPLY=($(compgen -o default -- "$partial_key"))
            #set +x
            #echo ------3
            return 0
            ;;
        -i|--inherit-collection)
            #echo ------4
            #set -x
            COMPREPLY=($(compgen -o default -- "$partial_key"))
            #set +x
            #echo ------4
            return 0
            ;;
        -M|--merge-mode)
            declare -a modes
            modes=(a ask r use-right l use-left)
            #echo ------5
            #set -x
            COMPREPLY=($(compgen -W "${modes[*]}" -- "$partial_key"))
            #set +x
            #echo ------5
            return 0
    esac

    case "${COMP_WORDS[COMP_CWORD]}" in 
        --*)
            #echo ------6
            #set -x
            COMPREPLY=($(compgen -W "${long_opts[*]}" -- "$partial_key"))
            #set +x
            #echo ------6
            return 0
            ;;
        -*)
            #echo ------7
            #set -x
            COMPREPLY=($(compgen -W "${short_opts[*]} ${long_opts[*]}" -- "$partial_key"))
            #set +x
            #echo ------7
            return 0
            ;;
        *)
            _PATHS_COLLECTION_COMPLETIONS
            return 0
            ;;
    esac

    ## figure out how many positional args we have
    #local positional_arg_num=-1
    #local arg
    #local opt
    #declare -a opts_with_arg=(-p --path -b --bookmark -f --function -r --relative-to)
    #for arg in "${COMP_WORDS[@]}"; do
    #    [[ "$arg" =~ ^- ]] || ((positional_arg_num++))
    #    for opt in "${opts_with_arg[@]}"; do
    #        [[ "$arg" == "$opt" ]] && { ((positional_arg_num--)); break; }
    #    done
    #done

    ## complete the positional arguments
    #case $positional_arg_num in
    #    1)
    #        # offer existing bookmarks as options for the case of reassigning a bookmark
    #        _PATHS_COLLECTION_COMPLETIONS
    #        ;;
    #esac

    #set +x
}
complete -F _PATHS_ML_COMPLETION ${_PATHS_FUNC_ALIASES[_PATHS_ML]}


# save path
_PATHS_SP () {
    local path_db
    local state_db
    # source database
    eval "$(_PATHS_LOAD_STATE)"
    eval "$(_PATHS_LOAD_DB "${_PATHS_CURRENT_COLLECTION:-${state_db[current_collection]}}")"
    local path
    local bookmark_name
    local rel_bookmark_name
    local func_def
    local func_name
    local path_specified=true
    local no_confirm=false
    local OVERRIDE_COLLECTION

    declare -a positional_opts
    while [[ $# -gt 0 && ! "$1" == "--" ]]; do case "$1" in
        -c|--collection)
            shift
            eval "$(_PATHS_LOAD_DB "$1")"
            OVERRIDE_COLLECTION=$1
            ;;
        -p|--path)  # accepts one immediate argument, which is the path on disk the bookmark will point to
            shift
            path="$1"
            ;;
        -b|--bookmark)
            shift
            bookmark_name="$1"
            ;;
        -r|--relative-to)
            shift
            rel_bookmark_name="$1"
            ;;
        -f|--function)
            shift
            func_name="$1"
            ;;
        -n|--no-confirm)
            no_confirm=true
            ;;
        -h|--help)  # do help
            echo "Usage:"
            echo "    $FUNCNAME [-b|--bookmark <bookmark_name>] [-f|--function <function_name>] [-p|--path <path>] [-n|--no-confirm]"
            echo "    ${FUNCNAME//?/ } [-r|--relative-to <bookmark>] [-c|--collection <collection>] [-h|--help] [<bookmark_name>] [<path>]"
            echo
            echo "    This function creates a new bookmark. It can be used to modify existing bookmarks by overwriting them. Note"
            echo "    that between 0 and 2 positional arguments can be accepted. Both positional arguments can be specified with"
            echo "    a named option (which takes precidence if used simultaneously)."
            echo
            echo "    Key assumptions:"
            echo "        - if no path is specified, the current directory is used"
            echo "        - if no bookmark name is specified, the default bookmark is used"
            echo "        - if a function is supplied, the <path> argument is ignored"
            echo "        - bookmarks are checked for validity at creation, except for function bookmarks"
            echo
            echo "    Options:"
            echo "        -b|--bookmark <arg>       name of the bookmark to create/update"
            echo "        -c|--collection <arg>     name of the collection to use for the duration of this command"
            echo "        -f|--function <arg>       name of the function to use for this bookmark; the function definition is stored"
            echo "        -p|--path <arg>           the path which the bookmark points to"
            echo "        -r|--relative-to <arg>    the name of an existing bookmark with which this bookmark will be relative to"
            echo "        -n|--no-confirm           do not ask for confirmation prior to overwriting an existing bookmark"
            echo "        -h|--help                 print this help"
            echo
            echo "Bookmark types:"
            echo "    - absolute path: a fixed path that is fully resolved with realpath"
            echo "    - relative path: a partial path relative to any existing bookmark"
            echo "    - function-yielded: (advanced usage) a bash function which returns a real directory without a newline;"
            echo "        can be utilized directly or as the root for a relative path. This allows for dynamic bookmarks."
            echo
            echo "Related aliases:"
            alias | while read -r line; do [[ $line == *$FUNCNAME* ]] && echo "    $line"; done
            echo
  
            return 0
            ;;
        [^-]*)  # pos1: bookmark name, pos2: path on disk
            positional_opts+=("$1")
            # is this shift required? or will it break things?
            # A: it will break things
            #shift
            ;;
        *)
            printf -- "Error: unrecognized option '%s'\n" "$1" >&2
            return 1
            ;;
    esac; shift; done
    if [[ "$1" == '--' ]]; then shift; fi

    if [[ ${#positional_opts[@]} -gt 0 ]]; then
        set -- "${positional_opts[@]}" "$@"
    fi

    if [[ $# -gt 2 ]]; then
        echo "Error: recieved $# positional arguments; expecting 2 or less" >&2
        return 1
    fi

    # set the bookmark name if unset
    if [[ -z "$bookmark_name" ]]; then
        if [[ -n "$1" ]]; then
            bookmark_name="$1"
        else
            bookmark_name="${state_db[default_bookmark_name]}"
        fi
    fi

    # set the path if unset
    if [[ -z "$path" ]]; then
        if [[ -n "$2" ]]; then
            path="$2"
        else
            path_specified=false
            path="$(pwd)"
        fi
    fi

    # sanity checks; need more of these
    if [[ -n "$func_name" ]] && $path_specified; then
        echo "Error: cannot specify both a path and a function" >&2
        return 1
    fi
    if [[ -n "$func_name" && -n "$rel_bookmark_name" ]]; then
        echo "Error: please define the function-based bookmark first and the bookmark relative to it second; function-based bookmars must be the root of a path" >&2
        return 1
    fi

    # check if there will an overwrite and handle it appropriately
    if ! $no_confirm && [[ "$bookmark_name" != "${state_db[default_bookmark_name]}" && "${path_db["$bookmark_name"]}" != ""  ]]; then
        local ans
        local ask=true
        while $ask; do
            read -p "would you like to overwite existing bookmark '$bookmark_name'? (y/n) " ans
            ask=true
            case "${ans,,}" in
                y|yes)
                    ask=false
                    ans=true
                    ;;
                n|no)
                    ask=false
                    ans=false
                    ;;
            esac
        done
        $ans || { echo "save aborted"; return 0; }
    fi

    # do we have a func?
    # do we have a relative?
    # is it an absolute?
    if [[ -n "$func_name" ]]; then
        if [[ "$bookmark_name" == "${state_db[default_bookmark_name]}" ]]; then
            echo >&2 "Error: cannot use the default bookmark to store a function-based bookmark."
            return 1
        fi

        # get the function definition and make sure it was retrieved correctly
        func_def="$(declare -pf "$func_name")"
        if [[ -z "$func_def" || $? -ne 0 ]]; then
            echo "Error: function does not exist or lacks a definition" >&2
            return 1
        fi

        # construct the function bookmark and return early
        local name_len=${#func_name}

        path_db[$bookmark_name]=f${name_len}:$func_name$func_def
        _PATHS_SAVE_DB "${state_db[current_collection]}"

        echo "Saved function '$func_name' as '$bookmark_name'"
        return 0

    elif [[ -n "$rel_bookmark_name" ]]; then
        if [[ "$bookmark_name" == "${state_db[default_bookmark_name]}" ]]; then
            echo >&2 "Error: cannot use the default bookmark to store a relative bookmark."
            return 1
        fi

        # does the relative parent bookmark exist?
        if [[ -z ${path_db[$rel_bookmark_name]} ]]; then
            echo "Error: the bookmark '$rel_bookmark_name' does not exist" >&2
            return 1
        fi

        local resolved_path="$(realpath --relative-to "$(_PATHS_PP -R "$rel_bookmark_name")" "$path")"

        local name_len=${#rel_bookmark_name}
        resolved_path="r$name_len:$rel_bookmark_name$resolved_path"

        path_db[$bookmark_name]=$resolved_path
        _PATHS_SAVE_DB "${state_db[current_collection]}"

        echo "Saved '$path' as '$bookmark_name' relative to '$rel_bookmark_name'"
        return 0

    else
        local resolved_path="$(realpath "$path")"
        if [[ ! -e "$resolved_path" ]]; then
            echo "Error: path '$path' ($resolved_path) does not exist" >&2
            return 1
        elif [[ ! -d "$resolved_path" ]]; then
            echo "Error: path '$path' ($resolved_path) is not a directory" >&2
            return 1
        fi
    fi

    if [[ "$bookmark_name" == "${state_db[default_bookmark_name]}" ]]; then
        state_db[default_bookmark_value]="$resolved_path"
        _PATHS_SAVE_STATE
        echo "Saved path '$path' as the default bookmark"
    else
        path_db[$bookmark_name]=$resolved_path
        _PATHS_SAVE_DB "${state_db[current_collection]}"
        echo "Saved path '$path' as '$bookmark_name'"
    fi

    return 0

}

#goto path
_PATHS_GP () {
    local path_db
    local state_db
    # source database
    eval "$(_PATHS_LOAD_STATE)"
    eval "$(_PATHS_LOAD_DB "${_PATHS_CURRENT_COLLECTION:-${state_db[current_collection]}}")"
    local path
    local bookmark_name
    local OVERRIDE_COLLECTION

    declare -a positional_opts
    while [[ $# -gt 0 && ! "$1" == "--" ]]; do case "$1" in
        -c|--collection)
            shift
            eval "$(_PATHS_LOAD_DB "$1")"
            OVERRIDE_COLLECTION=$1
            ;;
        -b|--bookmark)
            shift
            bookmark_name="$1"
            ;;
        -h|--help)
            # do help
            echo "Usage:"
            echo "    $FUNCNAME [-b|--bookmark <bookmark_name>] [-c|--collection <collection>] [-h|--help] [<bookmark_name>]"
            echo
            echo "    This function changes the working directory to the location specified by the given bookmark."
            echo
            echo "    Key assumptions:"
            echo "        - if no bookmark name is specified, the default bookmark is used"
            echo
            echo "    Options:"
            echo "        -b|--bookmark <arg>     name of the bookmark to cd to"
            echo "        -c|--collection <arg>   name of the collection to use for the duration of this command"
            echo "        -h|--help               print this help"
            echo
            echo "Bookmark types:"
            echo "    - absolute path: a fixed path that is fully resolved with realpath"
            echo "    - relative path: a partial path relative to any existing bookmark"
            echo "    - function-yielded: (advanced usage) a bash function which returns a real directory without a newline;"
            echo "        can be utilized directly or as the root for a relative path. This allows for dynamic bookmarks."
            echo
            echo "Related aliases:"
            alias | while read -r line; do [[ $line == *$FUNCNAME* ]] && echo "    $line"; done
            echo
            return 0
            ;;
        [^-]*)
            positional_opts+=("$1")
            # is this shift required? or will it break things?
            # A: it will break things
            #shift
            ;;
    esac; shift; done
    if [[ "$1" == '--' ]]; then shift; fi

    if [[ ${#positional_opts[@]} -gt 0 ]]; then
        set -- "${positional_opts[@]}" "$@"
    fi

    # set the bookmark name if unset
    if [[ -z "$bookmark_name" ]]; then
        if [[ -n "$1" ]]; then
            bookmark_name="$1"
        else
            bookmark_name="${state_db[default_bookmark_name]}"
        fi
    fi

    # sanity check the name
    path=${path_db[$bookmark_name]}
    if [[ $bookmark_name == "${state_db[default_bookmark_name]}" ]]; then
        path=${state_db[default_bookmark_value]}
    elif [[ -z "$path" ]]; then
        echo "Error: nonexistent bookmark '$bookmark_name" >&2
        return 1
    else
        if ! path="$(_PATHS_PP -R "$bookmark_name")"; then
            local retval=$?
            echo >&2 "Error: path resolution failed; see previous errors"
            return $retval
        fi
    fi

    # make sure path exists
    if [[ -d "$path" ]]; then
        cd "$path" && echo "working directory is now '$(pwd)'"
        return 0
    else
        if [[ -e $path ]]; then
            echo >&2 "Error: destination is not a directory; destination: '$path'"
        else
            echo "Error: destination does not exist; destination: '$path'" >&2
        fi
        return 1
    fi
}

# delete path
_PATHS_DP () {
    local path_db
    local state_db
    # source database
    eval "$(_PATHS_LOAD_STATE)"
    eval "$(_PATHS_LOAD_DB "${_PATHS_CURRENT_COLLECTION:-${state_db[current_collection]}}")"

    local clean_absolute=false
    local clean_functions=false
    local clean_relative=false
    local confirm=true
    local OVERRIDE_COLLECTION

    declare -a positional_opts
    while [[ $# -gt 0 && ! "$1" == "--" ]]; do case "$1" in
        -c|--collection)
            shift
            eval "$(_PATHS_LOAD_DB "$1")"
            OVERRIDE_COLLECTION=$1
            ;;
        -ca|--clean-absolute)
            clean_absolute=true
            ;;
        -cf|--clean-functions)
            clean_functions=true
            # this is a no-op for now; not sure how or if to handle
            echo "Info: '$1' not yet implemented"
            ;;
        -cr|--clean-relative)
            clean_relative=true
            echo "Info: '$1' not yet implemented"
            # this is a no-op for now; complicated to handle and must be done after absolute path cleaning
            # this also needs to check first if the bookmark is broken internally and second if the path exists when resolved
            # this is also really complicated considering the root may be a function
            ;;
        -n|--no-confirm)  # specifically for --clean-*; skips prompts to delete and just does it
            confirm=false
            ;;
        -h|--help)
            # do help
            echo "Usage:"
            echo "    $FUNCNAME [-c|--collection <collection>] [-ca|--clean-absolute] [-cf|--clean-functions] [-cr|--clean-relative] [-n|--no-confirm]"
            echo "    ${FUNCNAME//?/ } [-h|--help] [<bookmark_name> ...]"
            echo
            echo "    This function permanently removes bookmarks from the database. By default it will ask if you want to delete"
            echo "    each bookmark. There are various clean flags that will collect broken bookmarks for deletion. Multiple"
            echo "    bookmarks can be supplied to a single call of this function."
            echo
            echo "    Key assumptions:"
            echo "        - if no bookmark name is specified, do nothing"
            echo "        - supplied bookmarks are not globs or regular expressions, they must be exact matches"
            echo
            echo "    Options:"
            echo "        -c|--collection <arg>     name of the collection to use for the duration of this command"
            echo "        -ca|--clean-absolute      remove absolute bookmarks that do not resolve to an existing path"
            echo "        -cf|--clean-functions     NOT YET IMPLEMENTED: clean up function-based bookarks"
            echo "        -cr|--clean-relative      NOT YET IMPLEMENTED: clean up relative bookmarks that fail to resolve to an existing path"
            echo "        -n|--no-confirm           do not ask for confirmation before removal"
            echo "        -h|--help                 print this help"
            echo
            echo "Bookmark types:"
            echo "    - absolute path: a fixed path that is fully resolved with realpath"
            echo "    - relative path: a partial path relative to any existing bookmark"
            echo "    - function-yielded: (advanced usage) a bash function which returns a real directory without a newline;"
            echo "        can be utilized directly or as the root for a relative path. This allows for dynamic bookmarks."
            echo
            echo "Related aliases:"
            alias | while read -r line; do [[ $line == *$FUNCNAME* ]] && echo "    $line"; done
            echo
            return 0
            ;;
        [^-]*)
            positional_opts+=("$1")
            # is this shift required? or will it break things?
            # A: it will break things
            #shift
            ;;
    esac; shift; done
    if [[ "$1" == '--' ]]; then shift; fi

    if [[ ${#positional_opts[@]} -gt 0 ]]; then
        set -- "${positional_opts[@]}" "$@"
    fi

    if $clean_absolute; then
        # foreach bookmark, resolve and if result is nonexistent
        local bookmark
        for bookmark in "${!path_db[@]}"; do
            if [[ ${path_db[$bookmark]:0:1} == "/" && ! -d ${path_db[$bookmark]} ]]; then
                echo -n "The path specified by '$bookmark' no longer exists or is not a directory, "
                if [[ $bookmark == "${state_db[default_bookmark_name]}" ]]; then
                    echo "it is also the default bookmark, skipping ..."
                    continue
                fi
                if $confirm; then
                    local ans
                    local ask=true
                    while $ask; do
                        read -p "would you like to remove this bookmark? (y/n) " ans
                        ask=true
                        case "${ans,,}" in
                            y|yes)
                                ask=false
                                ;;
                            n|no)
                                ask=false
                                continue 2
                                ;;
                        esac
                    done
                fi
                echo "removing '$bookmark'"
                unset "path_db[$bookmark]"
            fi
        done
    fi

    local retval=0
    local bookmark
    for bookmark in "$@"; do
        if [[ -z ${path_db[$bookmark]} ]]; then
            echo "Error: bookmark '$bookmark' not found" >&2
            return 1
        fi
        if [[ $bookmark == "${state_db[default_bookmark_name]}" ]]; then
            echo "Error: refusing to delete the default bookmark" >&2
            retval=2
            continue
        fi

        if $confirm; then
            local ans
            local ask=true
            while $ask; do
                read -p "Would you like to remove '$bookmark' from your bookmarks? (y/n) " ans
                ask=true
                case "${ans,,}" in
                    y|yes)
                        ask=false
                        ;;
                    n|no)
                        ask=false
                        continue 2
                        ;;
                esac
            done
        fi
        echo "removing '$bookmark'"
        unset "path_db[$bookmark]"
    done

    _PATHS_SAVE_DB "${state_db[current_collection]}"
    return $retval
}

# print paths
_PATHS_PP () {
    local path_db
    local state_db
    # source database
    eval "$(_PATHS_LOAD_STATE)"
    eval "$(_PATHS_LOAD_DB "${_PATHS_CURRENT_COLLECTION:-${state_db[current_collection]}}")"

    local resolve=false
    local exact_resolve=false
    local return_function_body=false
    local OVERRIDE_COLLECTION

    declare -a positional_opts
    while [[ $# -gt 0 && ! "$1" == "--" ]]; do case "$1" in
        -c|--collection)
            shift
            unset path_db
            local path_db
            eval "$(_PATHS_LOAD_DB "$1")"
            OVERRIDE_COLLECTION=$1
            ;;
        -R|--exact-resolve)
            exact_resolve=true
            ;;
        -r|--resolve)
            resolve=true
            ;;
        -f|--function-body)
            return_function_body=true
            ;;
        -h|--help)
            # do help
            echo "Usage:"
            echo "    $FUNCNAME [-c|--collection <collection>] [-R|--exact-resolve] [-r|--resolve] [-f|--function-body] [-h|--help] [<regex> ...]"
            echo
            echo "    This function prints existing bookmarks. It can print all bookmarks or a subset specified by the supplied"
            echo "    regular expressions."
            echo
            echo "    Key assumptions:"
            echo "        - if no bookmark name is specified, print all stored paths"
            echo "        - regex matching for lookup is always used, except when specifying --exact-resolve or -R"
            echo "        - accepts any quantity of bookmark name expressions, but must receive exactly one when doing an exact-resolve"
            echo "        - except when printing all stored paths, the user does not care to see the default bookmark in search"
            echo "            results unless it is directly named"
            echo
            echo "    Options:"
            echo "        -c|--collection <arg>  name of the collection to use for the duration of this command"
            echo "        -f|--function-body     for function-yielded bookmarks, print the entire function; USE WITH -R or --exact-resolve"
            echo "        -r|--resolve           resolve results in the 'Bookmark Value' column to real paths on disk"
            echo "        -R|--exact-resolve     resolve one bookmark, exactly named, to a path"
            echo "        -h|--help              print this help"
            echo
            echo "Bookmark types:"
            echo "    - absolute path: a fixed path that is fully resolved with realpath"
            echo "    - relative path: a partial path relative to any existing bookmark"
            echo "    - function-yielded: (advanced usage) a bash function which returns a real directory without a newline;"
            echo "        can be utilized directly or as the root for a relative path. This allows for dynamic bookmarks."
            echo
            echo "Related aliases:"
            alias | while read -r line; do [[ $line == *$FUNCNAME* ]] && echo "    $line"; done
            echo
            return 0
            ;;
        [^-]*)
            positional_opts+=("$1")
            # is this shift required? or will it break things?
            # A: it will break things
            #shift
            ;;
    esac; shift; done
    if [[ "$1" == '--' ]]; then shift; fi

    if [[ ${#positional_opts[@]} -gt 0 ]]; then
        set -- "${positional_opts[@]}" "$@"
    fi

    if $exact_resolve; then
        if [[ ${#@} -ne 1 ]]; then
            echo "Error: expected exactly one positional argument (subshell depth: $BASH_SUBSHELL, function stack: "${FUNCNAME[*]}")" >&2
            return 1
        fi

        local key="$1"
        local value
        if [[ $key == "${state_db[default_bookmark_name]}" ]]; then
            value=${state_db[default_bookmark_value]}
        else
            value=${path_db[$key]}
        fi

        # do we have an exact match?
        if [[ "$value" == "" ]]; then
            echo "Error: expected exact bookmark name, but found no such bookmark '$key' (subshell depth: $BASH_SUBSHELL, function stack: ${FUNCNAME[*]})" >&2
            return 1
        else
            # what type of bookmark do we have?
            local value

            if ! value=$(_PATHS_FORMAT_BM "$key" true $return_function_body); then
                return 1
            fi

            printf -- "%s\n" "$value"
        fi

        return 0
    fi

    # exact_resolve not specified

    # for each positional argument

    # are we resolving values?

    # main body

    # need to determine what to print
        # all search values are positional
        # search values can be exact or regex

    # need to decide how to print each thing we found
        # resolve results?
            # -r general resolution
            # -R expect one exact bookmark name and will resolve its value; error otherwise

        # separate match results with "---\n"
        # sort each match's results based on bookmark name
        # match result groupings are in the order of searches supplied
        # if one search term is supplied, no sep or header needed
            # else: each result set headed by "searching for <term>:\n"

        # print key-value pairs using tab-separation piped to column always -- assumption is regex search unless -R given
            # _PATHS_PP flag to opt for output truncation at terminal width or perform smarter wrapping (look into -W)
            # column is outdated on several actively used systems, so need to fall back to usage without "-L" or "-W" options

        # functions will only not be truncated when requested by the user

    $return_function_body && echo Warning: ignoring option to return full function body: please resolve a single bookmark to use this feature >&2
    return_function_body=false

    local collection
    collection=${_PATHS_CURRENT_COLLECTION:-${state_db[current_collection]}}
    [[ -n $OVERRIDE_COLLECTION ]] && collection="$OVERRIDE_COLLECTION"
    printf -- "Current collection: %s\n\n" "$collection"

    local tab_char
    printf -v tab_char "\t"
    if [[ ${#@} -eq 0 ]] ; then  # print all
        {
            printf -- "Bookmark Name\tBookmark Value\n"  # table headers
            printf -- "-------------\t--------------\n"

            # print the default bookmark first
            printf -- "default (%s)\t%s\n" "${state_db[default_bookmark_name]}" "$(_PATHS_FORMAT_BM "${state_db[default_bookmark_name]}" $resolve $return_function_body)"
            echo
            #unset "path_db[${state_db[default_bookmark_name]}]"

            # print sorted bookmarks less the default
            local key
            for key in "${!path_db[@]}"; do
                printf -- "%s\t%s\n" "$key" "$(_PATHS_FORMAT_BM "$key" $resolve $return_function_body || echo "<error>")"
            done | sort
        } | { column -t -s "$tab_char" -W2 -L 2>/dev/null || column -t -s "$tab_char"; }

        return 0
    fi

    ## one argument plus exact match -> don't need special formatting or bookmark name in the output


    local tab_char
    printf -v tab_char "\t"
    # handle multiple expressions plus regex
    {
        printf -- "Search Expression\tMatched Bookmarks\tBookmark Value\n"
        printf -- "-----------------\t-----------------\t--------------\n"
        local arg
        local exact
        for arg in "$@"; do
            printf -- "%s" "$arg"  # print the search expression
            {
                # handle regex lookup here by iterating over the keys and regex testing each one
                local print_return=true
                local key
                for key in "${!path_db[@]}" "${state_db[default_bookmark_name]}"; do
                    #[[ "$key" == "$arg" ]] && exact=" (exact)" || exact=""
                    #[[ "$key" != "${state_db[default_bookmark_name]}" && "$key" =~ $arg ]] && printf -- "\t%s%s\t%s\n" "$key" "$exact" "$(_PATHS_FORMAT_BM "$key" $resolve $return_function_body)"

                    local print_match=false
                    if [[ "$key" == "$arg" ]]; then
                        print_match=true
                        exact=" (exact)"
                    elif [[ "$key" != "${state_db[default_bookmark_name]}" && "$key" =~ $arg ]]; then
                        print_match=true
                        exact=""
                    fi

                    if $print_match; then
                        print_return=false
                        printf -- "\t%s%s\t%s\n" "$key" "$exact" "$(_PATHS_FORMAT_BM "$key" $resolve $return_function_body || echo "<error>")"
                    fi

                done
                $print_return && echo
            } | sort  # sort each match group
        done
    } | { column -t -s "$tab_char" -W3 -L 2>/dev/null || column -t -s "$tab_char"; }
}

_PATHS_FORMAT_BM () {
    local bookmark_name="$1"
    local resolve="$2"
    local return_function_body="$3"
    local collection

    collection=$_PATHS_CURRENT_COLLECTION
    [[ -n $OVERRIDE_COLLECTION ]] && collection="$OVERRIDE_COLLECTION"

    local path_db
    local state_db
    eval "$(_PATHS_LOAD_STATE)"
    eval "$(_PATHS_LOAD_DB "${collection:-${state_db[current_collection]}}")"

    local value
    if [[ $bookmark_name == "${state_db[default_bookmark_name]}" ]]; then
        value=${state_db[default_bookmark_value]}
    else
        value=${path_db[$bookmark_name]}
    fi
    case "$value" in
        /*)
            printf -- "%s" "${value//\/\//\/}"
            ;;
        f*)
            # execute function and return value
            local result
            if [[ "$value" =~ ^f([0-9]+):(.+)$ ]]; then
                local len=${BASH_REMATCH[1]}
                local func_name="${BASH_REMATCH[2]::$len}"
                local func_def="${BASH_REMATCH[2]:$len}"

                if ! $return_function_body && $resolve; then
                    if ! result="$(eval "$func_def" && "$func_name")"; then
                        echo "Error: evaluation of function '$func_name' failed (subshell depth: $BASH_SUBSHELL, function stack: ${FUNCNAME[*]})" >&2
                        return 1
                    fi
                    printf -- "%s" "$result"
                    return 0
                fi

                if $return_function_body; then
                    # print the entire function definition
                    printf -- "%s" "$func_def"
                    return 0
                else
                    # reduce the length and use escaped chars for one-line display based on the available space
                    local line_length=$(tput cols)
                    local chars_before=${#func_def}
                    local ellipsis=""
                    func_def="${func_def::$line_length/3}"
                    [[ ${#func_def} -lt $chars_before ]] && ellipsis=" ..."
                    printf -- "%q%s" "${func_def}" "$ellipsis"
                    return 0
                fi
            else
                # truncate to first parenthesis and then limit to 20 characters (should prevent long lines and newline chars)
                value="${value%(*}"
                value="${value::20}"

                echo "Error: parsing of bookmark '${value::20}' (truncated) failed (subshell depth: $BASH_SUBSHELL, function stack: ${FUNCNAME[*]})" >&2
                return 1
            fi
            ;;
        r*)
            # recursive lookup of the relative bookmark's pointer
            if [[ "$value" =~ ^r([0-9]+):(.+)$ ]]; then
                local len=${BASH_REMATCH[1]}
                local bookmark_name="${BASH_REMATCH[2]::$len}"
                local relative_path="${BASH_REMATCH[2]:$len}"

                if $resolve; then
                    if result="$(_PATHS_PP -R "$bookmark_name")"; then
                        local resolved_path="$result/$relative_path"
                        printf -- "%s" "${resolved_path//\/\//\/}"
                        return 0
                    else
                        echo "Error: recursive lookup of bookmark '$bookmark_name' failed (subshell depth: $BASH_SUBSHELL, function stack: ${FUNCNAME[*]})" >&2
                        return 1
                    fi
                fi

                printf -- "[%s]/%s" "$bookmark_name" "$relative_path"
                return 0

            else
                echo "Error: parsing of bookmark '${value::20}' (truncated) failed (subshell depth: $BASH_SUBSHELL, function stack: ${FUNCNAME[*]})" >&2
                return 1
            fi

            ;;
        *)
            echo "Error: invalid bookmark value returned by key '$bookmark_name' (subshell depth: $BASH_SUBSHELL, function stack: ${FUNCNAME[*]})" >&2
            return 1
    esac
}

_PATHS_ML () {
    declare -A path_db
    declare -A state_db
    eval "$(_PATHS_LOAD_STATE)"

    local confirm=true

    local management_modes=""


    # merge modes: use-left, use-right, ask
    local merge_mode=ask
    # scope options for current collection: system, shell
    local current_scope=system
    local reset_scope=false
    local arg
    local check_args=$'arg=${management_modes:(-1)}; (( $# >= ${argc[arg]} + 1 )) || { echo >&2 "Error: \'$1\' requires ${argc[arg]} arg(s)"; return 1; }'
    declare -i argc

    declare -a management_args
    declare -a positional_opts
    while [[ $# -gt 0 && ! "$1" == "--" ]]; do case "$1" in
        -l|--list-collections)
            management_modes+=l
            ;;
        -r|--rename-collection)
            argc[r]=2
            management_modes+=r
            eval "$check_args"
            management_args+=("$2" "$3")
            shift ${argc[arg]}
            ;;
        -d|--delete-collection)
            argc[d]=1
            management_modes+=d
            eval "$check_args"
            management_args+=("$2")
            shift ${argc[arg]}
            ;;
        -c|--create-collection)
            argc[c]=1
            management_modes+=c
            eval "$check_args"
            management_args+=("$2")
            shift ${argc[arg]}
            ;;
        -C|--copy-collection)
            argc[C]=2
            management_modes+=C
            eval "$check_args"
            management_args+=("$2" "$3")
            shift ${argc[arg]}
            ;;
        -m|--merge-collections)
            argc[m]=3
            management_modes+=m
            eval "$check_args"
            management_args+=("$2" "$3" "$4")
            shift ${argc[arg]}
            ;;
        -M|--merge-mode)
            argc[M]=1
            merge_mode=$2
            (( $# >= ${argc[M]} + 1 )) || { echo >&2 "Error: '$1' requires ${argc[M]} arg(s)"; return 1; }
            case "$merge_mode" in
                [alr]|ask|use-left|use-right) ;;
                *)
                    echo >&2 "Error: merge mode '$merge_mode' is invalid"
                    return 1
                    ;;
            esac
            shift ${argc[M]}
            ;;
        -s|--subscribe-to-collection)
            argc[s]=2
            management_modes+=s
            eval "$check_args"
            management_args+=("$2" "$3")
            shift ${argc[arg]}
            ;;
        -i|--inherit-collection)
            argc[i]=2
            management_modes+=i
            eval "$check_args"
            management_args+=("$2" "$3")
            shift ${argc[arg]}
            ;;
        -u|--update-subscription)
            argc[u]=1
            management_modes+=u
            eval "$check_args"
            management_args+=("$2")
            shift ${argc[arg]}
            ;;
        -S|--shell-scope)
            management_modes+=S
            current_scope=shell
            ;;
        -R|--reset-scope)
            management_modes+=R
            current_scope=system
            reset_scope=true
            ;;
        -n|--no-confirm)
            confirm=false
            ;;
        -h|--help)
            # do help
            echo "Usage:"
            echo "    $FUNCNAME [<collection_name>] [-h|--help] [-c|--create-collection <collection_name>] [-d|--delete-collection <collection_name>]"
            echo "    ${FUNCNAME//?/ } [-r|--rename-collection <original_name> <new_name>] [-C|--copy-collection <original_name> <new_name>]"
            echo "    ${FUNCNAME//?/ } [-m|--merge-collections <new_collection> <left_collection> <right_collection>] [-M|--merge-mode <mode>]"
            echo "    ${FUNCNAME//?/ } [-i|--inherit-collection <new_collection> <source_collection_path>]"
            echo "    ${FUNCNAME//?/ } [-s|--subscribe-to-collection <new_collection> <source_collection_path>] [-u|--update-subscription <collection_name>]"
            echo "    ${FUNCNAME//?/ } [-u|--update-subscription <collection_name>] [-l|--list-collections] [-S|--shell-scope]"
            echo "    ${FUNCNAME//?/ } [-R|--reset-scope] [-n|--no-confirm]"
            echo
            echo "    This function is used to manage the library of path bookmark collections. To manage bookmarks in a specific collection, see"
            echo "    the PATHS_PP help text. It can temporarily set a different working collection for the current shell instance, subscribe to"
            echo "    collections from other users*, and do various operations on the set of collections to rename, delete, and merge them. Multiple"
            echo "    operations can be chained in a single call, and the set of collections can be listed between operations."
            echo
            echo "    Positional arguments:"
            echo "        collection_name  this collection will be the new working collection for subsequent paths.bash function calls"
            echo "        <none>           if no arguments of any kind are specified, the default behavior is that of -l"
            echo
            echo "    Options:"
            echo "        -c|--create-collection    creates an empty path bookmark collection"
            echo "        -C|--copy-collection      copies an existing collection into a new collection"
            echo "        -d|--delete-collection    delete a collection"
            echo "        -i|--inherit-collection   live-subscribes to an external (other user) collection via symlink"
            echo "        -l|--list-collections     lists all of the collections in the user's library"
            echo "        -m|--merge-collections    this can be used to merge two collections into a new collection"
            echo "        -M|--merge-mode           this specifies the merge function's conflict resolution strategy; available"
            echo "                                      options are: 'ask', 'use-left', or 'use-right' (abbreviated as 'a', 'l', and 'r')"
            echo "        -n|--no-confirm           for select dangerous options, this short-circuits the y/n prompts to yes"
            echo "        -r|--rename-collection    rename a collection"
            echo "        -R|--reset-scope          cancels the effects of -S in the current shell"
            echo "        -s|--subscribe-to-collection"
            echo "                                  subscribes to a collection with manual update frequency; the collection is copied"
            echo "                                      at time of subscription and can be updated using -u"
            echo "        -S|--shell-scope          when used with the 'collection_name' positional, this sets the working collection"
            echo "                                      for the current shell; undo with -R"
            echo "        -u|--update-subscription  update a subscription created with -s; copies a new version of the collection"
            echo "                                      into the user's library"
            echo "        -h|--help                 display this help"
            echo
            echo "Collection types:"
            echo "    normal/self   these are created and managed by you and are not subscriptions"
            echo "    inherited     these are symlinked to another user's collection and live-update"
            echo "    subscribed    these are copied at creation into the user's library and can be updated at manual intervals"
            echo
            echo "Interpreting the 'Meta' column:"
            echo "    This column displays attributes of a collection. These are listed below:"
            echo "        (C)     this collection is the current collection"
            echo "        (I)     this collection is inherited from an external source"
            echo "        (S)     this collection is a subscription to an external source"
            echo "        (-age)  this is time elapsed since the subscription was last updated, hence the '-' to indicate out-of-date potential;"
            echo "                    h = hours, d = days, m = months, y = years"
            echo
            echo "*"
            echo "The core functionality of this script relies on sourcing *.collection.sh files, which are BASH scripts. If you"
            echo "do not trust the other users on your system, do not use the subscription features. It is worth noting that while"
            echo "malicious collection files are a novel attack vector, they are a simple and highly-exploitable one. PROCEED WITH"
            echo "CAUTION."
            echo 
            echo "Related aliases:"
            alias | while read -r line; do [[ $line == *$FUNCNAME* ]] && echo "    $line"; done
            echo
            return 0
            ;;
        [^-]*)
            positional_opts+=("$1")
            ;;
    esac; shift; done
    if [[ $1 == '--' ]]; then shift; fi

    if [[ ${#positional_opts[@]} -gt 0 ]]; then
        set -- "${positional_opts[@]}" "$@"
    fi

    # swapping current collection should be done as default behavior for positional arg
    local current_collection
    current_collection=$1

    # if no operation specified, list collections
    if [[ ${#management_modes} -eq 0 && -z $current_collection ]]; then
        management_modes+=l
    fi

    local tab_char
    printf -v tab_char "\t"

    local current_mode
    local drop_count
    while (( ${#management_modes} > 0 )); do
        drop_count=0
        current_mode=${management_modes:0:1}
        management_modes=${management_modes:1}
        case $current_mode in
            l)
                local current_collection
                current_collection=${_PATHS_CURRENT_COLLECTION:-${state_db[current_collection]}}
                printf -- "Library:             %s\n" "$(realpath -e "$_PATHS_LIBRARY" || echo "<error: realpath failed for \$_PATHS_LIBRARY>")"
                printf -- "Current collection:  %s\n" "$current_collection"
                echo
                {
                    printf -- "Collection Name\tMeta\tCollection Path\n"  # table headers
                    printf -- "---------------\t----\t---------------\n"

                    local meta
                    local now mtime age hour day month year
                    now=$(date +%s)
                    hour=3600
                    day=86400
                    month=$(( 30 * day ))
                    year=$(( 365 * day ))

                    local collection
                    local name
                    for collection in "$_PATHS_LIBRARY"/*.collection.sh; do
                        name=${collection##*/}
                        name=${name%.collection.sh}
                        
                        meta=
                        if [[ $name == "$current_collection" ]]; then
                            meta+="(C)"
                        fi

                        if [[ -L $collection ]]; then
                            meta+="(I)"
                        elif [[ -e $collection.src ]]; then
                            meta+="(S)(-"

                            mtime=$(stat -c %Y "$collection.src")
                            age=$(( now - mtime ))

                            if (( age < day )); then
                                meta+="$(( age / hour ))h"
                            elif (( age < month )); then
                                meta+="$(( age / day ))d"
                            elif (( age < year )); then
                                meta+="$(( age / month ))m"
                            else
                                meta+="$(( age / year ))y"
                            fi
                            meta+=")"
                        else
                            meta=
                        fi

                        #meta=${meta//)(/) (}
                        printf -- "%s\t%s\t%s\n" "$name" "$meta" "$(realpath -e "$collection" || echo "$collection <error: realpath failed; broken link?>")"; 
                    done
                } | { column -t -s "$tab_char" -W3 -L 2>/dev/null || column -t -s "$tab_char"; }
                ;;
            d)
                local name
                name=$management_args
                drop_count=${argc[u]}

                local path
                path=$_PATHS_LIBRARY/$name.collection.sh

                if [[ ! -e $path ]]; then
                    echo >&2 "Error: collection '$name' does not exist (collection path = '$path')"
                    return 1
                fi

                if $confirm; then
                    local ans
                    local ask=true
                    while $ask; do
                        read -p "delete: would you like to delete collection '$name'? (y/n) " ans
                        ask=true
                        case "${ans,,}" in
                            y|yes)
                                ask=false
                                ans=true
                                ;;
                            n|no)
                                ask=false
                                ans=false
                                ;;
                        esac
                    done
                    $ans || { management_args=("${management_args[@]:drop_count}"); continue; }
                fi

                local p
                local error=false
                for p in "$path" "$path.src"; do
                    [[ -e $p ]] || continue

                    if ! rm -f "$p"; then
                        echo >&2 "Error: failed to remove '$p'"
                        error=true
                    else
                        if [[ $p == *.src ]]; then
                            echo "removed subscription source link for collection '$name'"
                        else
                            echo "removed collection '$name'"
                        fi
                    fi
                done

                $error && return 1

                if [[ $name == "${state_db[current_collection]}" ]]; then
                    echo >&2 "Warning: collection '$name' was the current collection; please set a new current collection"
                fi
                ;;
            r|C)
                local cmd
                case $current_mode in
                    r) cmd=mv ;;
                    C) cmd=cp ;;
                esac

                local orig_name
                local new_name
                drop_count=${argc[$current_mode]}

                orig_name=${management_args[0]}
                new_name=${management_args[1]}

                local orig_path
                local new_path

                orig_path=$_PATHS_LIBRARY/$orig_name.collection.sh
                new_path=$_PATHS_LIBRARY/$new_name.collection.sh
                
                if [[ ! -e $orig_path ]]; then
                    echo >&2 "Error: collection '$orig_name' does not exist"
                    return 1
                fi

                local operation
                case $cmd in
                    mv) operation=rename ;;
                    cp) operation=copy ;;
                esac
                if [[ -e $new_path ]]; then
                    if $confirm; then
                        local ans
                        local ask=true
                        while $ask; do
                            read -p "$operation: would you like to overwite existing collection '$new_name'? (y/n) " ans
                            ask=true
                            case "${ans,,}" in
                                y|yes)
                                    ask=false
                                    ans=true
                                    ;;
                                n|no)
                                    ask=false
                                    ans=false
                                    ;;
                            esac
                        done
                        $ans || { management_args=("${management_args[@]:drop_count}"); continue; }
                    else
                        echo >&2 "Warning: collection '$new_name' will be overwritten"
                    fi
                fi

                $cmd -f "$orig_path" "$new_path"

                if [[ -e $orig_path.src ]]; then
                    $cmd -f "$orig_path.src" "$new_path.src"
                fi

                if [[ $cmd == mv && $orig_name == "${state_db[current_collection]}" ]]; then
                    state_db[current_collection]=$new_name
                    _PATHS_SAVE_STATE
                    echo >&2 "Warning: current collection was '$orig_name' and is now '$new_name'"
                fi
                ;;
            c)
                local name
                name=$management_args
                drop_count=${argc[c]}

                local path
                path=$_PATHS_LIBRARY/$name.collection.sh
                if [[ -e $path ]]; then
                    echo >&2 "Error: cannot create collection '$name' because it already exists ($path)"
                    return 1
                fi

                if ! NO_WARN=1 _PATHS_SAVE_DB "$name" && echo "created collection '$name'"; then
                    echo >&2 "Error: failed to create new collection '$name'"
                    return 1
                fi
                ;;
            m)
                local left_coll
                local right_coll
                local new_coll
                drop_count=${argc[m]}

                new_coll=${management_args[0]}
                left_coll=${management_args[1]}
                right_coll=${management_args[2]}

                local new_coll_path
                local left_coll_path
                local right_coll_path

                new_coll_path=$_PATHS_LIBRARY/$new_coll.collection.sh
                left_coll_path=$_PATHS_LIBRARY/$left_coll.collection.sh
                right_coll_path=$_PATHS_LIBRARY/$right_coll.collection.sh
                
                local error=false
                if [[ -e $new_coll_path ]]; then
                    echo >&2 "Error: collection '$new_coll' exists"
                    error=true
                fi
                if [[ ! -e $left_coll_path ]]; then
                    echo >&2 "Error: collection '$left_coll' does not exist"
                    error=true
                fi

                if [[ ! -e $right_coll_path ]]; then
                    echo >&2 "Error: collection '$right_coll' does not exist"
                    error=true
                fi

                $error && return 1

                #declare -A left_db
                #declare -A right_db
                declare -A new_db
                local definition

                definition=$(_PATHS_LOAD_DB "$left_coll")
                eval "declare -A left_db=${definition#*=}"

                definition=$(_PATHS_LOAD_DB "$right_coll")
                eval "declare -A right_db=${definition#*=}"

                # input validated, so this matching is safe
                case $merge_mode in
                    a*)
                        local bm
                        declare -A bm_ocurrences
                        for bm in "${!left_db[@]}" "${!right_db[@]}"; do
                            bm_ocurrences[$bm]+=a
                        done

                        local left_bm
                        local right_bm
                        for bm in "${!bm_ocurrences[@]}"; do
                            if (( ${#bm_ocurrences[$bm]} == 2 )); then
                                # ask
                                local ans
                                local ask=true
                                while $ask; do
                                    read -p "merge: for bookmark '$bm', pick value from '$left_coll' (left) or '$right_coll' (right)? (l/r) " ans
                                    ask=true
                                    case "${ans,,}" in
                                        l|left)
                                            ask=false
                                            ans=left_bm
                                            ;;
                                        r|right)
                                            ask=false
                                            ans=right_bm
                                            ;;
                                    esac
                                done
                                left_bm=${left_db[$bm]}
                                right_bm=${right_db[$bm]}
                                new_db[$bm]=${!ans}
                            else
                                left_bm=${left_db[$bm]}
                                right_bm=${right_db[$bm]}
                                new_db[$bm]=${left_bm:-$right_bm}
                            fi
                        done
                        ;;
                    *l*)
                        for key in "${!left_db[@]}"; do
                            right_db[$key]=${left_db[$key]}
                        done

                        for key in "${!right_db[@]}"; do
                            new_db[$key]=${right_db[$key]}
                        done
                        ;;
                    *r*)
                        for key in "${!right_db[@]}"; do
                            left_db[$key]=${right_db[$key]}
                        done

                        for key in "${!left_db[@]}"; do
                            new_db[$key]=${left_db[$key]}
                        done
                        ;;
                esac

                unset path_db
                declare -A path_db
                for key in "${!new_db[@]}"; do
                    path_db[$key]=${new_db[$key]}
                done

                if NO_WARN=1 _PATHS_SAVE_DB "$new_coll"; then
                    echo "saved merged collection as '$new_coll'"
                else
                    echo >&2 "Error: failed to create new collection '$new_coll'"
                    return 1
                fi
                ;;
            i|s|u)
                local name
                local path

                name=${management_args[0]}

                if [[ $current_mode == u ]]; then
                    if ! path="$(realpath -e "$_PATHS_LIBRARY/$name.collection.sh.src")"; then
                        echo >&2  "Error: failed to resolve link to original collection for '$name'"
                        return 1
                    fi
                else
                    path=${management_args[1]}
                fi

                drop_count=${argc[$current_mode]}

                if ! path="$(realpath -e "$path")"; then
                    echo >&2 "Error: cannot find source collection at '$path' (it does not exist or is not readable)"
                    return 1
                fi

                local inheritance_name
                inheritance_name=${path##*/}
                inheritance_name=${inheritance_name%.collection.sh}

                if [[ $path != */${inheritance_name}.collection.sh || ! -f $path ]]; then
                    echo >&2 "Error: input collection file does not look like a collection of path bookmarks"
                    return 1
                fi

                local dst_path
                dst_path=$_PATHS_LIBRARY/$name.collection.sh
                if [[ $current_mode != u && -e $dst_path ]]; then
                    echo >&2 "Error: collection '$name' already exists ($dst_path)"
                    return 1
                fi

                case $current_mode in
                    i)
                        if ! ( \cd "$_PATHS_LIBRARY" && ln -s -T "$path" "${dst_path##*/}"; ); then
                            echo >&2 "Error: failed to create link for new collection '$name'"
                            return 1
                        fi
                        ;;
                    s|u)
                        if ! cp "$path" "$dst_path"; then
                            echo >&2 "Error: failed to produce facsimile of collection located at '$path'"
                            return 1
                        fi
                        if ! ( \cd "$_PATHS_LIBRARY" && ln -f -s -T "$path" "${dst_path##*/}.src"; ); then
                            echo >&2 "Error: failed to create link for source of collection '$name'"
                            return 1
                        fi
                        ;;
                esac
                local prefix
                case $current_mode in
                    i) echo "inherit: added collection '$name'" ;;
                    s) echo "subscribe: added collection '$name'" ;;
                    u) echo "update: updated collection '$name'" ;;
                esac
                ;;
        esac

        management_args=("${management_args[@]:drop_count}")
    done

    $reset_scope && unset _PATHS_CURRENT_COLLECTION

    # if positional argument specified, switch to that collection, if possible; doing this last
    if [[ ! -z $current_collection && $current_collection != "${state_db[current_collection]}" ]]; then
        local path
        path=$_PATHS_LIBRARY/$current_collection.collection.sh
        if [[ ! -e $path ]]; then
            if [[ -L $path ]]; then
                echo >&2 "Error: cannot set current collection to '$current_collection'; link to original is broken"
            else
                echo >&2 "Error: cannot set current collection to '$current_collection'; collection does not exist (path = '$path')"
            fi

            return 1
        fi

        case $current_scope in
            system) 
                state_db[current_collection]=$current_collection
                _PATHS_SAVE_STATE || return 1
                ;;
            shell)
                export _PATHS_CURRENT_COLLECTION="$current_collection"
                ;;
        esac
        echo "set '$current_collection' as the current collection"
    fi

}

unset _PATHS_FUNC_ALIASES
