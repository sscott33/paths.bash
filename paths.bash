# MIT License
# 
# Copyright (c) 2022–2023 Samuel Odell Scott.
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

set -x
export _PATHS_PATH_DB_FILE="/home/esmaosc/lantern_day/2024-04-02/.path_db.bash"
    # stored dictionary is path_db
export _PATHS_DEFAULT_BM_NAME=_default

# allow for renaming the functions in case of collision; note that "complete" commands will need to be updated with new aliases
alias gp=_PATHS_GP
alias sp=_PATHS_SP
alias dp=_PATHS_DP
alias pp=_PATHS_PP

_key_completions() {
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
        COMPREPLY=($(printf '%q\n' "${completions[@]}"))
    fi
}

# add completion functionality to all functions except sp; not sure how to do completion based on argument position
complete -F _key_completions gp
complete -F _key_completions dp
complete -F _key_completions pp

# sp positional completion
_sp_completion() {
    case $COMP_CWORD in
        1)
            # complete directory names
            COMPREPLY=($(compgen -o dirnames -- "${COMP_WORDS[COMP_CWORD]}"))
            ;;
        2)
            # offer existing bookmarks as options for the case of reassigning a bookmark
            _key_completions
            ;;
    esac
}
complete -F _sp_completion sp

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
		-p|--path)
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
        -h|--help)
            # do help
            echo "Insert help text here..."
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
    #if [[ -n "$func_name" && -z "$bookmark_name" ]]; then
    #    # refuse default bookmark as a function?
    #    echo "Error: please specify a bookmark name" >&2
    #    return 1
    #fi

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

        #local resolved_path="$(realpath --relative-to "$path")"
        local resolved_path="$(realpath --relative-to "$(_PATHS_PP -r "$bookmark_name")" "$path")"
        # not yet sure how to check this path until _PATHS_PP resolves it
        #if [[ ! -e "$resolved_path" ]]; then
        #    echo "Error: path '$path' ($resolved_path) does not exist" >&2
        #    return 1
        #fi

        local name_len=${#bookmark_name}
        local old_path="$resolved_path"
        resolved_path="r$name_len:$bookmark_name$resolved_path"

        path_db["$bookmark_name"]="$resolved_path"
        declare -p path_db > "$_PATHS_PATH_DB_FILE"

        echo "Saved '$path' as '$old_path' relative to '$bookmark_name'"
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
        if [[ -z "$path_db["$bookmark_name"]" ]]; then
            echo "Error: $bookmark_name is not an existing bookmark" >&2
            return 1
        fi


        if [[ ! -d "$path" ]]; then
            echo "Error: '$path' does not exist or is not a directory" >&2
            return 1
        fi

        path="$(realpath --relative-to "$(_PATHS_PP -r "$bookmark_name")" "$path")"

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
            echo "Insert help text here..."
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
        if ! path="$(_PATHS_PP -r "$bookmark_name")"; then
            local retval=$?
            echo "Error: path resolution failed; see previous errors"
            return $?
        fi


#    elif [[ "${path:0:1}" == "/" ]]; then  # handle absolute path
#    elif [[ "$path" =~ ^(r|f)([0-9])+:(.+) ]]; then  # handle relative path or function-based bookmark
#        local type="${BASH_REMATCH[1]}"
#        local name_len=${BASH_REMATCH[2]}
#        local value="${BASH_REMATCH[3]}"
#
    fi

    # make sure path exists
    if [[ -e "$path" ]]; then
        cd "$path" && echo "working directory is now '$(pwd)'"
        return $?
    else
        echo "Error: destination does not exist; destination: '$path'" >&2
        return 1
    fi


    #return 0
    ####################
    case $# in
        0) # work with default
            path="${path_db[$_PATHS_DEFAULT_BM_NAME]}"
            ;;
        1) # work with named directory
            #path="${path_db["$1"]}"
            if ! path="$(_PATHS_PP -r "$1")"; then
                echo "Error: lookup of '$1' in the bookmark database failed" >&2
                return 1
            fi
            #path="$(realpath -e "$path")"
            ;;
        *) # print usage
            echo "HELP: use this function to go to a named path; will go to the default path if no path is specified; view choices with pp"
            return
            ;;
    esac

    if [[ -n "$path" ]]; then
        if [[ -d "$path" ]]; then
            # attempt to cd to the path; cd rarely returns a failure exit code, so print pwd just to be safe
            cd "$path" && echo "working directory is now '$(pwd)'"
        else
            echo "Error: '$path' does not exist or is not a directory" >&2
        fi
    else
        echo "Error: '$1' is not a path bookmark" >&2
        return 1
    fi
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
            ;;
        -cr|--clean-relative)
            clean_relative=true
            # this is a no-op for now; complicated to handle and must be done after absolute path cleaning
            # this also needs to check first if the bookmark is broken internally and second if the path exists when resolved
            # this is also really complicated considering the root may be a function
            ;;
        -n|--no-confirm)  # specifically for --clean-*; skips prompts to delete and just does it
            confirm=false
            ;;
        -h|--help)
            # do help
            echo "Insert help text here..."
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
                unset path_db["$bookmark"]
            fi
        done
    fi

    local bookmark
    for bookmark in "$@"; do
        if [[ -z "${path_db["$bookmark"]}" ]]; then
            echo "Error: bookmark '$bookmark' not found" >&2
            return 1
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
        unset path_db["$bookmark"]
    done

    declare -p path_db > "${_PATHS_PATH_DB_FILE}"
    return 0
    #########################
    case $# in
        0) # print usage
            echo "HELP: use this function to delete one or more path references by specifying their names; view path references with pp"
            return
            ;;
        *) # delete one or more named paths
            while [[ -n "$1" ]]; do
                [[ "$1" == "$_PATHS_DEFAULT_BM_NAME" ]] && echo "Error: refusing delete default entry: '$_PATHS_DEFAULT_BM_NAME'" >2 && shift && continue
                unset path_db["$1"] && echo "deleted reference to '$1'"
                shift
            done
            ;;
    esac
    # save database
    declare -p path_db > "${_PATHS_PATH_DB_FILE}"
}

# print paths
_PATHS_PP () {
    local path_db
    . "$_PATHS_PATH_DB_FILE"

    local key
    local path
    local value
    local resolve=false
    local prefix
    local parent
    local func_name
    local func_def

    # allow user to specify -r or --
    while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case "$1" in
        -r)
            resolve=true
            ;;
    esac; shift; done
    if [[ "$1" == '--' ]]; then shift; fi


    local starting_argument_count=$#
        # must store this because this variable will decrease with every "shift" call
    case $# in
        0) # print all bookmarks
            # print the default bookmark
            echo "$_PATHS_DEFAULT_BM_NAME (default) : ${path_db[$_PATHS_DEFAULT_BM_NAME]}"
            unset path_db[$_PATHS_DEFAULT_BM_NAME]

            # separate default and regular bookmarks with a blank line
            [[ ${#path_db[@]} -gt 0 ]] && echo

            # print the other bookmarks
            for key in "${!path_db[@]}"; do
                value="${path_db["$key"]}"
                value="$(_PATHS_FORMAT_BM "$value")"

                printf "%s\n" "$key : $value"
            done | sort
            ;;
        *) # print the requested bookmark(s); newline separated

            path="${path_db["$1"]}"

            while [[ -n "$1" ]]; do
                path="${path_db["$1"]}"
                if [[ -z "$path" ]]; then
                    unset path_db[$_PATHS_DEFAULT_BM_NAME]
                    for key in "${!path_db[@]}"; do
                        value="$(_PATHS_FORMAT_BM "${path_db["$key"]}")"
                        [[ "$key" =~ $1 ]] && printf "%s\n" "$key : $value"
                    done
                elif [[ $starting_argument_count -eq 1 ]]; then
                    # if there is only one bookmark and it's exactly named, print path without name -> useful for $(pp <bookmark>)
                    prefix="${path:0:1}"
                    if [[ "$prefix" == "f" ]]; then
                        #path="$(cut -d: -f3 <<<"$path")"
                        if [[ "$resolve" == "true" ]]; then
                            #func_name="$(cut -d: -f2 <<<"$path")"
                            func_name="${path#*:}"
                            func_def="${func_name#*:}"
                            func_name="${func_name%:*}"
                            if ! path="$(eval "$func_def" && "$func_name")"; then
                                echo Error: failure to execute $func_name, in bookmark $1 >&2
                                return 1
                            fi
                        else
                            # remove the first two elements of the entry
                            path="${path#*:}"
                            path="${path#*:}"
                        fi
                    elif [[ "$prefix" == "r" ]]; then
                        if [[ "$resolve" == "true" ]]; then
                            parent="$(cut -d: -f2 <<<"$path")"
                            parent="$(_PATHS_PP -r "$parent")"
                            path="$(cut -d: -f3 <<<"$path")"
                            path="$parent/$path"
                        else
                            path="${path:2}"
                        fi
                    elif [[ "$prefix" == "a" ]]; then
                        path="${path:2}"
                    fi
                    printf "%s\n" "$path"
                    #printf "%s\n" "$(_PATHS_FORMAT_BM "$path")"
                else
                    printf "%s\n" "$1 : $(_PATHS_FORMAT_BM "$path")"
                fi
                shift
            done | { [[ -z "$path" ]] && sort -u || cat; }
            ;;
    esac
}

_PATHS_FORMAT_BM () {
    local bookmark="$1"
    if [[ "${bookmark:0:1}" == "f" ]]; then
        bookmark="$(tr -s [:space:] ' ' <<<"$bookmark" | cut -d: -f3)"
        bookmark="${bookmark:0:30} ..."
    else
        bookmark="${bookmark:2}"
    fi

    printf "%s" "$bookmark"
}
set +x
