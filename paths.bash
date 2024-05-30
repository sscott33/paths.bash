# MIT License
#
# Copyright (c) 2022–2024 Samuel Odell Scott.
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

#set -x
#export _PATHS_PATH_DB_FILE="$HOME/.path_db.bash"
export _PATHS_PATH_DB_FILE="/home/sam/Documents/lantern_day/2024-05-14/paths.bash/.path_db.bash"
    # stored dictionary is path_db
export _PATHS_DEFAULT_BM_NAME=_default

# allow for renaming the functions in case of collision; note that "complete" commands will need to be updated with new aliases
alias gp=_PATHS_GP
alias sp=_PATHS_SP
alias dp=_PATHS_DP
alias pp=_PATHS_PP

_PATHS_KEY_COMPLETIONS() {
    # completion words come from the keys of the associative array stored in the file below
    local path_db
    . "$_PATHS_PATH_DB_FILE"

    # get the currently completing word
    local partial_key=${COMP_WORDS[COMP_CWORD]}

    # change IFS so that the completions can contain spaces
    # using $-string to get actual newline character
    local IFS=$'\n'

    # filter through keys based on currently completing word
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

# add completion functionality to all functions except sp; not sure how to do completion based on argument position
_PATHS_GP_COMPLETION () {
    declare -a short_opts=(-h -b)
    declare -a long_opts=(--help --bookmark)
    local partial_key="${COMP_WORDS[COMP_CWORD]}"

    case "${COMP_WORDS[COMP_CWORD-1]}" in
        -b|--bookmark)
            _PATHS_KEY_COMPLETIONS
            ;;
    esac

    case "${COMP_WORDS[COMP_CWORD]}" in 
        --*)
            COMPREPLY=($(compgen -W "${long_opts[*]}" -- "$partial_key"))
            ;;
        -*)
            COMPREPLY=($(compgen -W "${short_opts[*]}" -- "$partial_key"))
            ;;
    esac

    #rm tmp
    # figure out how many positional args we have
    local positional_arg_num=-1
    local arg
    local opt
    local opts_with_arg=(-p --path -b --bookmark -f --function -r --relative-to)
    for arg in "${COMP_WORDS[@]}"; do
        [[ "$arg" =~ ^- ]] || ((positional_arg_num++))
        for opt in "${opts_with_arg[@]}"; do
            [[ "$arg" == "$opt" ]] && { ((positional_arg_num--)); break; }
        done
        #echo $arg >> tmp
    done

    #echo $positional_arg_num >> tmp
    # complete the positional arguments
    case $positional_arg_num in
        1)
            # offer existing bookmarks as options for the case of reassigning a bookmark
            _PATHS_KEY_COMPLETIONS
            ;;
    esac
}
complete -F _PATHS_GP_COMPLETION gp

_PATHS_DP_COMPLETION () {
    declare -a short_opts=(-h -ca -cf -cr -n)
    declare -a long_opts=(--help --clean-absolute --clean-functions --clean-relative --no-confirm)
    local partial_key="${COMP_WORDS[COMP_CWORD]}"

    case "${COMP_WORDS[COMP_CWORD]}" in 
        --*)
            COMPREPLY=($(compgen -W "${long_opts[*]}" -- "$partial_key"))
            ;;
        -*)
            COMPREPLY=($(compgen -W "${short_opts[*]}" -- "$partial_key"))
            ;;
        *)
            _PATHS_KEY_COMPLETIONS
            ;;
    esac
}
complete -F _PATHS_DP_COMPLETION dp

_PATHS_PP_COMPLETION () {
    declare -a short_opts=(-h -R -r -f)
    declare -a long_opts=(--help --exact-resolve --resolve --function-body)
    local partial_key="${COMP_WORDS[COMP_CWORD]}"

    case "${COMP_WORDS[COMP_CWORD]}" in 
        --*)
            COMPREPLY=($(compgen -W "${long_opts[*]}" -- "$partial_key"))
            ;;
        -*)
            COMPREPLY=($(compgen -W "${short_opts[*]}" -- "$partial_key"))
            ;;
        *)
            _PATHS_KEY_COMPLETIONS
            ;;
    esac
}
complete -F _PATHS_PP_COMPLETION pp

_PATHS_SP_COMPLETION () {
    declare -a short_opts=(-b -f -p -r -h)
    declare -a long_opts=(--bookmark --function --path --relative-to --help)
    local partial_key="${COMP_WORDS[COMP_CWORD]}"

    case "${COMP_WORDS[COMP_CWORD-1]}" in
        -b|--bookmark)
            _PATHS_KEY_COMPLETIONS
            ;;
        -f|--function)
            _PATHS_FUNC_COMPLETIONS
            ;;
        -p|--path)
            COMPREPLY=($(compgen -o dirnames -- "$partial_key"))
            ;;
        -r|--relative-to)
            _PATHS_KEY_COMPLETIONS
            ;;
    esac

    case "${COMP_WORDS[COMP_CWORD]}" in 
        --*)
            COMPREPLY=($(compgen -W "${long_opts[*]}" -- "$partial_key"))
            ;;
        -*)
            COMPREPLY=($(compgen -W "${short_opts[*]}" -- "$partial_key"))
            ;;
    esac

    #rm tmp
    # figure out how many positional args we have
    local positional_arg_num=-1
    local arg
    local opt
    local opts_with_arg=(-p --path -b --bookmark -f --function -r --relative-to)
    for arg in "${COMP_WORDS[@]}"; do
        [[ "$arg" =~ ^- ]] || ((positional_arg_num++))
        for opt in "${opts_with_arg[@]}"; do
            [[ "$arg" == "$opt" ]] && { ((positional_arg_num--)); break; }
        done
        #echo $arg >> tmp
    done

    #echo $positional_arg_num >> tmp
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
complete -F _PATHS_SP_COMPLETION sp

# init path database if it does not exist
if [[ ! -e "$_PATHS_PATH_DB_FILE" ]]; then
    declare -A path_db
    path_db[$_PATHS_DEFAULT_BM_NAME]="$HOME"
    declare -p path_db  > "$_PATHS_PATH_DB_FILE"
    unset path_db
fi

# save path
_PATHS_SP () {
    local path_db
    # source database
    . "$_PATHS_PATH_DB_FILE"
    local path
    local bookmark_name
    local rel_bookmark_name
    local func_def
    local func_name
    local path_specified=true

    declare -a positional_opts
    while [[ $# -gt 0 && ! "$1" == "--" ]]; do case "$1" in
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
        -h|--help)  # do help
            echo "Usage:"
            echo "    $FUNCNAME [-b|--bookmark <bookmark_name>] [-f|--function <function_name>] [-p|--path <path>]"
            echo "    ${FUNCNAME//[^[:space:]]/ } [-r|--relative-to <bookmark>] [-h|--help] [<bookmark_name>] [<path>]"
            echo
            echo "    This function creates a new bookmark. It can be used to modify existing bookmarks by overwriting them. Note"
            echo "    that between 0 and 2 positional arguments can be accepted. Both positional arguments can be specified with"
            echo "    a named option."
            echo
            echo "    Key assumptions:"
            echo "        - if no path is specified, the current directory is used"
            echo "        - if no bookmark name is specified, the default bookmark is used"
            echo "        - if a function is supplied, the <path> argument is ignored"
            echo "        - bookmarks are checked for validity at creation, except for function bookmarks"
            echo
            echo "Bookmark types:"
            echo "    - absolute path: a fixed path that is fully resolved with realpath"
            echo "    - relative path: a partial path relative to any existing bookmark"
            echo "    - function-yielded: (advanced usage) a bash function which returns a real directory without a newline;"
            echo "        can be utilized directly or as the root for a relative path. This allows for dynamic bookmarks."
            echo
            echo "Related aliases:"
            alias | awk '$0 ~ funcname {print "    " $0}' "funcname=$FUNCNAME"
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
            bookmark_name="$_PATHS_DEFAULT_BM_NAME"
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

    # do we have a func?
    # do we have a relative?
    # is it an absolute?
    if [[ -n "$func_name" ]]; then
        # get the function definition and make sure it was retrieved correctly
        func_def="$(declare -pf "$func_name")"
        if [[ -z "$func_def" || $? -ne 0 ]]; then
            echo "Error: function does not exist or lacks a definition" >&2
            return 1
        fi

        # construct the function bookmark and return early
        local name_len=${#func_name}

        path_db["$bookmark_name"]="f${name_len}:$func_name$func_def"
        declare -p path_db > "$_PATHS_PATH_DB_FILE"

        echo "Saved function '$func_name' as '$bookmark_name'"
        return 0

    elif [[ -n "$rel_bookmark_name" ]]; then
        # does the relative parent bookmark exist?
        if [[ -z "${path_db["$rel_bookmark_name"]}" ]]; then
            echo "Error: the bookmark '$rel_bookmark_name' does not exist" >&2
            return 1
        fi

        local resolved_path="$(realpath --relative-to "$(_PATHS_PP -R "$rel_bookmark_name")" "$path")"
        # not yet sure how to check this path until _PATHS_PP resolves it
        #if [[ ! -e "$resolved_path" ]]; then
        #    echo "Error: path '$path' ($resolved_path) does not exist" >&2
        #    return 1
        #fi

        local name_len=${#rel_bookmark_name}
        resolved_path="r$name_len:$rel_bookmark_name$resolved_path"

        path_db["$bookmark_name"]="$resolved_path"
        declare -p path_db > "$_PATHS_PATH_DB_FILE"

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

    path_db["$bookmark_name"]="$resolved_path"
    declare -p path_db > "$_PATHS_PATH_DB_FILE"

    if [[ "$bookmark_name" == "$_PATHS_DEFAULT_BM_NAME" ]]; then
        echo "Saved path '$path' as the default bookmark"
    else
        echo "Saved path '$path' as '$bookmark_name'"
    fi

    return 0

    #####################
    if [[ -n "$func_def" ]]; then
        # update this for confirmation text
        path="$func_name"
        path_db["$bookmark_name"]="f:$func_name:$func_def"

    elif [[ -n "$rel_bookmark_name" ]]; then
        if [[ -z "${path_db["$bookmark_name"]}" ]]; then
            echo "Error: $bookmark_name is not an existing bookmark" >&2
            return 1
        fi


        if [[ ! -d "$path" ]]; then
            echo "Error: '$path' does not exist or is not a directory" >&2
            return 1
        fi

        path="$(realpath --relative-to "$(_PATHS_PP -R "$bookmark_name")" "$path")"

        path_db["$rel_bookmark_name"]="r:$bookmark_name:$path"

        # remove relevant prefixes
        path="${path_db["$rel_bookmark_name"]:2}"

    elif [[ -d "$path" ]]; then
        path_db["$bookmark_name"]="a:$path"
    else
        echo "Error: '$path' does not exist or is not a directory" >&2
        return 1
    fi

    # need to handle other cases here
    bookmark_name="$rel_bookmark_name"
    if [[ "$bookmark_name" != "$_PATHS_DEFAULT_BM_NAME" ]]; then
        echo "saved path '$path' as '$bookmark_name'"
    else
        echo "saved path '$path'"
    fi
    # save database
    declare -p path_db > "$_PATHS_PATH_DB_FILE"
}

#goto path
_PATHS_GP () {
    local path_db
    # source database
    . "$_PATHS_PATH_DB_FILE"
    local path
    local bookmark_name

    declare -a positional_opts
    while [[ $# -gt 0 && ! "$1" == "--" ]]; do case "$1" in
        -b|--bookmark)
            shift
            bookmark_name="$1"
            ;;
        -h|--help)
            # do help
            echo "Usage:"
            echo "    $FUNCNAME [-b|--bookmark <bookmark_name>] [-h|--help] [<bookmark_name>]"
            echo
            echo "    This function changes the working directory to the location specified by the given bookmark."
            echo
            echo "    Key assumptions:"
            echo "        - if no bookmark name is specified, the default bookmark is used"
            echo
            echo "Bookmark types:"
            echo "    - absolute path: a fixed path that is fully resolved with realpath"
            echo "    - relative path: a partial path relative to any existing bookmark"
            echo "    - function-yielded: (advanced usage) a bash function which returns a real directory without a newline;"
            echo "        can be utilized directly or as the root for a relative path. This allows for dynamic bookmarks."
            echo
            echo "Related aliases:"
            alias | awk '$0 ~ funcname {print "    " $0}' "funcname=$FUNCNAME"
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
            bookmark_name="$_PATHS_DEFAULT_BM_NAME"
        fi
    fi

    # sanity check the name
    path="${path_db["$bookmark_name"]}"
    if [[ -z "$path" ]]; then
        echo "Error: nonexistent bookmark '$bookmark_name" >&2
        return 1
    else
        if ! path="$(_PATHS_PP -R "$bookmark_name")"; then
            local retval=$?
            echo "Error: path resolution failed; see previous errors"
            return $retval
        fi
    fi

    # make sure path exists
    if [[ -e "$path" ]]; then
        cd "$path" && echo "working directory is now '$(pwd)'"
        return $?
    else
        echo "Error: destination does not exist; destination: '$path'" >&2
        return 1
    fi


    return 0
}

# delete path
_PATHS_DP () {
    local path_db
    # source database
    . "$_PATHS_PATH_DB_FILE"

    local clean_absolute=false
    local clean_functions=false
    local clean_relative=false
    local confirm=true

    declare -a positional_opts
    while [[ $# -gt 0 && ! "$1" == "--" ]]; do case "$1" in
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
            echo "    $FUNCNAME [-ca|--clean-absolute] [-cf|--clean-functions] [-cr|--clean-relative] [-n|--no-confirm]"
            echo "    ${FUNCNAME//[^[:space:]]/ } [-h|--help] [<bookmark_name> ...]"
            echo
            echo "    This function permanently removes bookmarks from the database. By default it will ask if you want to delete"
            echo "    each bookmark. There are various clean flags that will collect broken bookmarks for deletion. Multiple"
            echo "    bookmarks can be supplied to a single call of this function."
            echo
            echo "    Key assumptions:"
            echo "        - if no bookmark name is specified, do nothing"
            echo "        - supplied bookmarks are not globs or regular expressions, they must be exact matches"
            echo
            echo "Bookmark types:"
            echo "    - absolute path: a fixed path that is fully resolved with realpath"
            echo "    - relative path: a partial path relative to any existing bookmark"
            echo "    - function-yielded: (advanced usage) a bash function which returns a real directory without a newline;"
            echo "        can be utilized directly or as the root for a relative path. This allows for dynamic bookmarks."
            echo
            echo "Related aliases:"
            alias | awk '$0 ~ funcname {print "    " $0}' "funcname=$FUNCNAME"
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
            if [[ "${path_db["$bookmark"]:0:1}" == "/" && ! -d "${path_db["$bookmark"]}" ]]; then
                echo -n "The path specified by '$bookmark' no longer exists or is not a directory, "
                if [[ "$bookmark" == "$_PATHS_DEFAULT_BM_NAME" ]]; then
                    echo "it is also the default bookmark, skipping ..."
                    continue
                fi
                if $confirm; then
                    local ans
                    local ask=true
                    while $ask; do
                        read -p "would you like to remove this bookmark? (y/n) " ans
                        ask=false
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

    local bookmark
    for bookmark in "$@"; do
        if [[ -z "${path_db["$bookmark"]}" ]]; then
            echo "Error: bookmark '$bookmark' not found" >&2
            return 1
        fi
        if [[ "$bookmark" == "$_PATHS_DEFAULT_BM_NAME" ]]; then
            echo "Error: refusing to delete the default bookmark" >&2
            continue
        fi

        if $confirm; then
            local ans
            local ask=true
            while $ask; do
                read -p "Would you like to remove '$bookmark' from your bookmarks? (y/n) " ans
                ask=false
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

    declare -p path_db > "${_PATHS_PATH_DB_FILE}"
    return 0
}

# print paths
_PATHS_PP () {
    local path_db
    # source database
    . "$_PATHS_PATH_DB_FILE"

    local resolve=false
    local exact_resolve=false
    local return_function_body=false

    declare -a positional_opts
    while [[ $# -gt 0 && ! "$1" == "--" ]]; do case "$1" in
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
            echo "    $FUNCNAME [-R|--exact-resolve] [-r|--resolve] [-f|--function-body] [-h|--help] [<regex> ...]"
            echo
            echo "    This function prints existing bookmarks. It can print all bookmarks or a subset specified by the supplied"
            echo "    regular expressions."
            echo
            echo "    Key assumptions:"
            echo "        - if no bookmark name is specified, print all stored paths"
            echo "        - if one bookmark name is specified AND is an exact match, only the lookup value will be returned"
            echo "        - exact (non-regex) match of <regex> is attempted first, so <regex> may need to be more explicit"
            echo "        - except when printing all stored paths, the user does not care to see the default bookmark in search"
            echo "            results unless it is directly named"
            echo
            echo "Bookmark types:"
            echo "    - absolute path: a fixed path that is fully resolved with realpath"
            echo "    - relative path: a partial path relative to any existing bookmark"
            echo "    - function-yielded: (advanced usage) a bash function which returns a real directory without a newline;"
            echo "        can be utilized directly or as the root for a relative path. This allows for dynamic bookmarks."
            echo
            echo "Related aliases:"
            alias | awk '$0 ~ funcname {print "    " $0}' "funcname=$FUNCNAME"
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
        local value="${path_db["$key"]}"

        # do we have an exact match?
        if [[ "$value" == "" ]]; then
            echo "Error: expected exact bookmark name, but found no such bookmark '$key' (subshell depth: $BASH_SUBSHELL, function stack: ${FUNCNAME[*]})" >&2
            return 1
        else
            # what type of bookmark do we have?
            printf -- "%s" "$(_PATHS_FORMAT_BM "$key" true false)"
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

        # print key-value pairs using tab-separation piped to column
            # _PATHS_PP flag to opt for output truncation at terminal width or perform smarter wrapping (look into -W)
            # column is outdated on several actively used systems, so need to fall back to usage without "-L" or "-W" options

        # functions will only not be truncated when requested by the user

    local tab_char
    printf -v tab_char "\t"
    if [[ ${#@} -eq 0 ]] ; then  # print all
        {
            printf -- "Bookmark Name\tBookmark Value\n"  # table headers
            printf -- "-------------\t--------------\n"

            # print the default bookmark first
            printf -- "default (%s)\t%s\n" "$_PATHS_DEFAULT_BM_NAME" "$(_PATHS_FORMAT_BM "$_PATHS_DEFAULT_BM_NAME" $resolve $return_function_body)"
            #printf -- "-----\n"
            echo
            unset "path_db[$_PATHS_DEFAULT_BM_NAME]"

            # print sorted bookmarks less the default
            local key
            for key in "${!path_db[@]}"; do
                #echo resolve: $resolve >&2
                printf -- "%s\t%s\n" "$key" "$(_PATHS_FORMAT_BM "$key" $resolve $return_function_body)"
            done | sort
        } | { column -t -s "$tab_char" -W2 -L 2>/dev/null || column -t -s "$tab_char"; }

        return 0
    fi

    # one argument plus exact match -> don't need special formatting or bookmark name in the output
    local value="${path_db["$1"]}"
    if [[ ${#@} -eq 1 && "$value" != "" ]]; then
        local result="$(_PATHS_FORMAT_BM "$1" $resolve $return_function_body)"
        printf -- "%s\n" "$result"
        return 0
    fi


    local tab_char
    printf -v tab_char "\t"
    # handle multiple expressions plus regex
    {
        printf -- "Search Expression\tMatched Bookmarks\tBookmark Value\n"
        printf -- "-----------------\t-----------------\t--------------\n"
        local arg
        for arg in "$@"; do
            printf -- "%s" "$arg"  # print the search expression
            {
                local value="${path_db["$arg"]}"
                if [[ "$value" != "" ]]; then
                    # handle exact match
                    local result="$(_PATHS_FORMAT_BM "$arg" $resolve $return_function_body)"
                    printf -- "\t%s\t%s\n" "$arg (exact)" "$result"
                else
                    # handle regex lookup here by iterating over the keys and regex testing each one
                    local key
                    for key in "${!path_db[@]}"; do
                        [[ "$key" != "$_PATHS_DEFAULT_BM_NAME" && "$key" =~ $arg ]] && printf -- "\t%s\t%s\n" "$key" "$(_PATHS_FORMAT_BM "$key" $resolve $return_function_body)"
                    done
                fi
            } | sort  # sort each match group
        done
    } | { column -t -s "$tab_char" -W3 -L 2>/dev/null || column -t -s "$tab_char"; }
}

_PATHS_FORMAT_BM () {
    local bookmark_name="$1"
    local resolve="$2"
    local return_function_body="$3"

    local path_db
    . "$_PATHS_PATH_DB_FILE"

    local value="${path_db["$bookmark_name"]}"
    case "$value" in
        /*)
            printf -- "%s" "$value"
            ;;
        f*)
            # execute function and return value
            local result
            if [[ "$value" =~ ^f([0-9]+):(.+)$ ]]; then
                local len=${BASH_REMATCH[1]}
                local func_name="${BASH_REMATCH[2]::$len}"
                local func_def="${BASH_REMATCH[2]:$len}"

                if $resolve; then
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
                        printf -- "%s" "$resolved_path"
                        return 0
                    else
                        echo "Error: recursive lookup of bookmark '$value' failed (subshell depth: $BASH_SUBSHELL, function stack: ${FUNCNAME[*]})" >&2
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
    esac
}
#set +x
