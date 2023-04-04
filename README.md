# paths.bash

paths.bash is a Bash file containing several functions that work in conjunction to form a path bookmarking system for users of the Bash shell. It features two-character functions for accessing and managing the bookmarks. There is even tab-completion functionality. At present, there are no 'bookmark folders' or hierarchy to the bookmarks. All bookmarks are at the same depth and accessible directly by name. In the future, selecting and switching between independent sets of bookmarks may be possible.

## How to install

Clone this repo or directly download paths.bash and add a source of the file to your .bashrc or an equivalent config file. **Important note:** using paths.bash will create and continually overwrite a file in your user's home directory called `.path_db.bash`. If you want to change this before your first use, please see the *Advanced configuration* section of this README.

## Usage

The following are the Bash functions you use to interact with the bookmarking system and their accompanying mnemonics. Feel free to rename them as their functionality is self-contained. Just make sure to update the completion functions accordingly.
* sp — save path
* gp — goto path
* pp — print path(s)
* dp — delete path(s)

### sp

> $> sp \<directory\> \<bookmark_name\>

This function saves a path to the bookmarks database and accepts 0-2 arguments. The functionality changes according to the argument count. If no arguments are given, the current working directory is stored as the default bookmark. If one argument is given, that path is stored as the default bookmark. If two arguments are given, the second argument is the name of the bookmark to create/update with the given path.

### gp

> $> gp \<bookmark_name\>

This function changes the working directory to a bookmarked path. It accepts 0–1 arguments. If no arguments are given, it will change the working directory to the default bookmark's path. If one argument is given, it should be the name of a bookmark. gp will then cd to that bookmark's path.

### pp

> $> pp \[\<bookmark_name\> ...\]

This function accepts any number of arguments. If given a non-zero number of arguments, it prints out the given bookmarks and their associated paths. If no bookmark is given (zero arguments), then it will print out all bookmarks and their associated paths. Note that you can search the bookmarks with this function using incomplete bookmark names and regular expressions. The default bookmark is never searched for and will only be printed with a zero-argument pp call or if passed to pp exactly by name.

### dp

> $> dp \<bookmark_name\> ...

This function accepts one or more arguments. The arguments should be bookmark names and they will be deleted from the store of bookmarks. Use this with caution, as it will not prompt for confirmation.

## Advanced configuration

### The default bookmark

The default bookmark can be changed, but never deleted. The idea behind it is to store a temporary bookmark that can be easily used at a later time or in another instance of your shell. Since bookmarked paths are stored live into `.path_db.bash`, you can immediately access the default bookmark (and any other existing bookmarks) in another shell/terminal. This is useful if you want another terminal open to the same directory and need to navigate to the same path. Using the default bookmark will be explained in the subsections for sp and gp.

You can rename the bookmark used to reference the default bookmark by changing the value of `_PATHS_DEFAULT_BM_NAME`. Note that you should subsequently update the default bookmark to prevent breakage. The bookmark name used to store the old default directory will then be treated like a normal bookmark.

### Path DB

You can configure the location and name of the file storing your bookmarks by changing the value of `_PATHS_PATH_DB_FILE`.

### Function names

You can somewhat easily change the function names without breaking functionality (in case of collision). To do this, modify the aliases near the top of the file. Then update the "complete" functions corresponding to each alias.

### Environment

All environment variables and functions defined by this script are prefixed with `_PATHS_`.

There are two environment variables used by this script:
* `_PATHS_PATH_DB_FILE`
* `_PATHS_DEFAULT_BM_NAME`

The function names used to interface with the path database storing your bookmarks are aliases to the actual functions.

## Miscellaneous info

I originally wrote the bare bones for this late one Friday night, so I make no promises about functionality. However, I use this tool on a daily basis at my workplace, as do a number of my coworkers, so I do plan to fix bugs, improve existing features, and to add new functionality over time.

## License

See the associated LICENSE file in the repo. This licence is also duplicated inside paths.bash.
