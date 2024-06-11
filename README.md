# paths.bash

paths.bash is a Bash file containing several functions that work in conjunction to form a path bookmarking system for users of the Bash shell. It features four functions for accessing and managing the bookmarks. All functions have tab-completion niceties. At present, there are no "bookmark folders" or hierarchy to the bookmarks. All bookmarks are at the same depth and accessible directly by name.

The main purpose of paths.bash is to improve quality of life for situations where someone needs to jump between directories often or has a complicated directory structure to traverse on a regular basis.

## How to install

Clone this repo or directly download paths.bash and add a source of the file to your .bashrc or an equivalent shell startup file. **Important note:** using paths.bash will create and continually overwrite a file in your user's home directory called `.path_db.bash`. If you want to change this before your first use, please see the *Advanced configuration* section of this README.

## Usage

The following are the current aliases to the four Bash functions you use to interact with the bookmarking system and their accompanying mnemonics. Feel free to modify them for your convenience or to avoid collisions with your environment (see *Advanced configuration* for instructions). This can be done because as the internal code uses the real names of the functions.
* sp — save path
* gp — goto path
* pp — print path(s)
* dp — delete path(s)

### sp

![Screenshot showing sp help text](/readme_deps/sp_help.png)

### gp

![Screenshot showing gp help text](/readme_deps/gp_help.png)

### pp

![Screenshot showing pp help text](/readme_deps/pp_help.png)

### dp

![Screenshot showing dp help text](/readme_deps/dp_help.png)

## Advanced configuration

Immediately following the license text at the top of paths.bash, you will find two `export` statements and one `declare` statement. These present the user with the ability to change where the path database is stored, what the default bookmark is called, and the aliases for the four primary functions.

### The default bookmark

The default bookmark can be changed, but never deleted. The idea behind it is to store a temporary bookmark that can be easily used at a later time or in another instance of your shell. Since bookmarked paths are stored live into `.path_db.bash`, you can immediately access the default bookmark (and any other existing bookmarks) in another shell/terminal. This is useful if you want another terminal open to the same directory and need to navigate to the same path. Using the default bookmark is explained in the help text for sp and gp.

You can rename the bookmark used to reference the default bookmark by changing the value of `_PATHS_DEFAULT_BM_NAME`. Note that you should subsequently update the default bookmark to prevent breakage. The bookmark name used to store the old default directory will then be treated like a normal bookmark.

### Path DB

You can configure the location and name of the file storing your bookmarks by changing the value of `_PATHS_PATH_DB_FILE`.

### Aliases

The real names of the functions are illustrated in the help text for each function. The user should utilize a convenient set of aliases to interact with these functions. The reason for this is to maintain a naming scheme that is unlikely to need refactoring while allowing the user to easily update these in case of collision or a difference of personal preferences.

If you want to change an alias, update the appropriate "value" in the `_PATHS_FUNC_ALIASES` associative array mappings.

### Environment

All environment variables and functions defined by this script are prefixed with `_PATHS_`.

There are two environment variables used by this script:
* `_PATHS_PATH_DB_FILE`
* `_PATHS_DEFAULT_BM_NAME`

The function names used to interface with the path database storing your bookmarks are aliases to the actual functions.

Note that the environment is briefly polluted with an associative array called `_PATHS_FUNC_ALIASES` to set up the aliasing. It is unset by the time paths.bash is fully sourced.

## Advanced usage

### Different types of bookmarks

This utility supports three types of bookmarks:

* absolute
    * The most intuitive type of bookmark
    * direct mapping to a path on disk
* relative
    * relative mapping to a path on disk with respect to another existing bookmark
* function-based/function-yielded
    * very advanced
    * uses a function to return a path on stdout to be utilized by paths.bash functions
    * cannot also be relative

### Utilizing functions

Creating a function-based bookmark is rather simple:
1. Define your function
2. Create the bookmark: `sp -f <function name> <bookmark name>`

paths.bash will store the function definition internally, so the function need not exist in the user's environment to be utilized. In fact, no definitions of functions in the user's environment are used after storing the function and utilizing a function-based bookmark should not pollute the user's environment as it is defined and called within a subshell during bookmark resolution.

Below is an example function I use regularly to anchor my navigation within a "workspace" (a programmatically-initialized directory containing several git repos and somewhat deep directory hierarchies) by finding the workspace's WORKSPACE file (which resides at its root). Note that it returns in an error state if it does not find what it is looking for. path.bash will check this return code and use it to determine if something went wrong during the function call. Any function utilized by paths.bash as a bookmark should return a real file path that is (preferably) a fully resolved path relative to root (/).

```
find_ws () {
(
    if [[ -f "$1" ]]; then
        \cd "$(dirname "$1")"
    else
        if [[ -d "$1" ]]; then
            \cd "$1"
        fi
    until [[ -e WORKSPACE ]]; do
        [[ "$(pwd)" == "/" ]] && return 1;
        \cd ..
    done
    printf "%s" "$(pwd)"
    return 0
)
}
```

This function is then stored into a bookmark which refers to the local workspace (that the shell's working directory is within):

```
sp -f find_ws lws
```

This can be used as the root bookmark for several relative bookmarks to useful areas within a workspace. These relative bookmarks then behave dynamically and can be used to navigate whatever workspace the user is currently within.

## Miscellaneous info

At time of writing, I do not have a formal way of testing this, so please keep an eye out for bugs and raise an issue if appropriate. I use this tool on a daily basis at my workplace, as do a number of my coworkers, so expect this utility to be maintained and slowly improved over time.

## License

See the associated LICENSE file in the repo. This licence is also duplicated inside paths.bash.
