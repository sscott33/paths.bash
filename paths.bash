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

export _PATHS_PATH_DB_FILE="$HOME/.path_db.bash"
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
    case $# in
        0) # work with pwd
            path="$(realpath "$(pwd)")"
            bookmark_name="$_PATHS_DEFAULT_BM_NAME"
            ;;
        1) # work with given directory
            path="$(realpath "$1")"
            bookmark_name="$_PATHS_DEFAULT_BM_NAME"
            ;;
        2) # named given directory
            path="$(realpath "$1")"
            bookmark_name="$2"
            ;;
        *) # print usage
            echo "HELP: use this function to save a path; first arg is the path (pwd if not specified); second arg is the reference name"
            return
            ;;
    esac

    if [[ -d "$path" ]]; then
        path_db["$bookmark_name"]="$path"
    else
        echo "Error: '$path' does not exist or is not a directory"
        return 1
    fi

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
    case $# in
        0) # work with default
            path="${path_db[$_PATHS_DEFAULT_BM_NAME]}"
            ;;
        1) # work with named directory
            path="${path_db["$1"]}"
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
            echo "Error: '$path' does not exist or is not a directory"
        fi
    else
        echo "Error: '$1' is not a path bookmark"
        return 1
    fi
}

# delete path
_PATHS_DP () {
    local path_db
    # source database
    . "$_PATHS_PATH_DB_FILE"
    case $# in
        0) # print usage
            echo "HELP: use this function to delete one or more path references by specifying their names; view path references with pp"
            return
            ;;
        *) # delete one or more named paths
            while [[ -n "$1" ]]; do
                [[ "$1" == "$_PATHS_DEFAULT_BM_NAME" ]] && echo "Error: refusing delete default entry: '$_PATHS_DEFAULT_BM_NAME'" && shift && continue
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
                printf "%s\n" "$key : ${path_db["$key"]}"
            done | sort
            ;;
        *) # print the requested bookmark(s); newline separated

            while [[ -n "$1" ]]; do
                path="${path_db["$1"]}"
                if [[ -z "$path" ]]; then
                    unset path_db[$_PATHS_DEFAULT_BM_NAME]
                    for key in "${!path_db[@]}"; do
                        [[ "$key" =~ $1 ]] && printf "%s\n" "$key : ${path_db["$key"]}"
                    done
                elif [[ $starting_argument_count -eq 1 ]]; then
                    # if there is only one bookmark and it's exactly named, print path without name -> useful for $(pp <bookmark>)
                    printf "%s\n" "$path"
                else
                    printf "%s\n" "$1 : $path"
                fi
                shift
            done | sort
            ;;
    esac
}
