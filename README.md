# paths.bash

paths.bash is a Bash file containing several functions that work in conjunction to form a path bookmarking system for users of the Bash shell. It features two-character functions for accessing and managing the bookmarks. There is even tab-completion functionality. At present, there are no 'bookmark folders' or hierarchy to the bookmarks. All bookmarks are at the same depth and accessible directly by name. In the future, selecting and switching between independent sets of bookmarks may be possible.

## How to install

Clone this repo or directly download paths.bash and add a source of the file to your .bashrc file. **Important note:** using paths.bash will create and continually overwrite a file in your user's home directory called ".path_db.bash". You can change this by editing the filename provided to the export command at the beginning of the file.

## Usage

The following are the Bash functions you use to interact with the bookmarking system and their accompanying mnemonics. Feel free to rename them as their functionality is self-contained. Just make sure to update the completion functions accordingly.
* sp — save path
* gp — goto path
* pp — print path(s)
* dp — delete path(s)

### The default bookmark

The default bookmark can be changed, but never deleted. The idea behind it is to store a temporary bookmark that can be easily used at a later time or in another instance of your shell. Since bookmarked paths are stored live into .path_db.bash, you can immediately access the default bookmark (and any other existing bookmarks) in another shell/terminal. This is useful if you want another terminal open to the same directory and need to navigate to the same path. Using the default bookmark will be explained in the subsections for sp and gp.

### sp

> $> sp <directory> <name>

This function saves a path to the bookmarks database and accepts 0-2 arguments. The functionality changes according to the argument count. If no arguments are given, the current working directory is stored as the default bookmark. If one argument is given, that path is stored as the default bookmark. If two arguments are given, the second argument is the name of the bookmark to create/update with the given path.

### gp

> $> gp <bookmark_name>

This function changes the working directory to a bookmarked path. It accepts 0–1 arguments. If no arguments are given, it will change the working directory to the default bookmark's path. If one argument is given, it should be the name of a bookmark. gp will then cd to that bookmark's path.

### pp

> $> pp <bookmark_name>

This function accepts 0–1 arguments. If given one argument, it prints out the given bookmark and its associated path. If no bookmark is given (zero arguments), then it will print out all bookmarks and their associated paths.

### dp

> $> dp <bookmark_name> ...

This function accepts one or more arguments. The arguments should be bookmark names and they will be deleted from the store of bookmarks. Use this with caution, as it will not prompt for confirmation.

## Miscellaneous info

I originally wrote the bare bones for this late one Friday night. It has not changed significantly since outside of the Bash completion features. The functions that comprise this tool are not robust and bugs are likely.

I do plan to fix bugs, improve existing features, and to add new functionality over time.

## License

See the associated LICENSE file in the repo. This licence is also duplicated inside paths.bash.
