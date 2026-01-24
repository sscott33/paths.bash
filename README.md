# paths.bash

`paths.bash` is a directory bookmarking and navigation system designed for systems running Bash with GNU Coreutils. It features five functions for accessing and managing the library. Bookmarks are organized into collections. This utility is designed for people who live in the shell, often jump between deep directory trees, and want something that addresses deficiencies in cache-based cd alternatives. All functions have tab-completion niceties.

You will get the most out of paths.bash if you need to traverse a complicated directory structure on a regular basis.

## How to install

Clone this repo or directly download paths.bash. Then, add a source of `paths.bash` to your `.bashrc` or an equivalent shell startup file. **Important note:** using paths.bash will create and continually overwrite a database on disk in your user's home directory called (by default) `.path_bookmarks`. If you want to change this before your first use, please see the *Advanced configuration* section of this README.

## Initialization

On first source, `paths.bash` will automatically initialize the library. This includes defining the default bookmark as a pointer to the user's home directory and creating an empty collection called *default*. It will also set the active collection to the *default* collection. If your needs do not require the added complexity of multiple bookmark collections, you need not use the `ml` function.

## Migration from pre-v4.0.0

If you started using `paths.bash` prior to version v4.0.0, you will need to migrate your bookmarks to the new storage system. You may use the script below to migrate your bookmarks to a collection in the new system. Note that the default storage locations for bookmarks in pre-v4.0.0 will not conflict with the new storage methodology. While I do not recommend this, it is technically possible to use both a pre-v4.0.0 and a version >= v4.0.0 concurrently, just not in the same shell.

```bash
./convert_path_db_to_v4.sh  # without arguments, print help

./convert_path_db_to_v4.sh <pre-v4.0.0_paths.bash_script> <newer_paths.bash_script> <collection_name_for_migrated_bookmarks>
```

The conversion script will create or overwrite a collection named by the user in the new database system. This collection will contain the user's current bookmarks. The value of the current default bookmark will also be transferred to the new system. The reason the script paths are required as arguments is to find the location of the user's current bookmarks (which may not live at the default path), ditto for the new script, and to use the appropriate utilities provided by each script to work with the bookmarks.

## Usage

The following are the current aliases to the Bash functions you use to interact with the bookmarking system and their accompanying mnemonics. Feel free to modify them for your convenience or to avoid collisions with your environment (see *Advanced configuration* for instructions). This can be done because as the internal code uses the real names of the functions. By default, all functions except for `ml` operate on the active collection and have the ability to temporarily operate on another collection. A short description of each function can be found in the subsequent subsections. Immediately below are the default aliases and their mnemonics:
* dp — delete path(s)
* gp — go-to path
* pp — print path(s)
* sp — save path
* ml — manage library

### dp (\_PATHS_DP)

This function allows you to delete one or more bookmarks from a collection. Unless the user specifies otherwise, it will confirm the deletion of each bookmark before removal. It must also complete successfully prior to applying any changes, so if you `Ctrl+C` out of execution, it will not apply any deletions. It also offers a cleaning feature to check for and remove broken absolute path bookmarks.

### gp (\_PATHS_GP)

This function allows the user change their current directory to the location specified by a bookmark. It accepts chaining of bookmarks for situations where first cd-ing to the path specified by one bookmark is required for another bookmark to resolve correctly. If you are new to this utility, this is a bit of a nonsensical situation to encounter, but if you create any function-based bookmarks (see *Advanced usage*), you may find this feature to be useful.

Note that if no bookmark name is provided, the default bookmark will be used.

### pp (\_PATHS_PP)

This function prints out the bookmarks in a collection. It sorts by bookmark name, can filter bookmark names using Bash regular expressions, and can display bookmarks in a variety of representations. The notation for unresolved bookmarks that are not an absolute path is as follows:
* `[bookmark_name]/<path>` indicates a bookmark relative to the bookmark specified by `bookmark_name`
* `$'...` indicates a truncated function definition (limited to 20 characters)

You can opt to have all displayed bookmarks fully resolved to their path on disk. You can also use this function on a single bookmark to retrieve its fully resolved path, if it is a function-based bookmark, you may optionally retrieve its underlying Bash function.

### sp (\_PATHS_SP)

This function is used to create new bookmarks and add them to a collection. It can only create one at a time. It supports reduced positional arguments to intuitively save the working directory as the bookmark specified by the first argument. This syntax is how most users tend to create their bookmarks.

Note that if no bookmark name is provided, the default bookmark will be used.

### ml (\_PATHS_ML)

This function is used to manage the library's collections of bookmarks. It supports creating, merging, renaming, and deleting collections. It can also perform multiple operations at once, in the order specified on the command line. It is used to list the libraries collections as well as to set the active/current collection. It also provides a feature to set the active collection for the current shell only. Note that the behavior of this feature may be confusing and is perhaps best avoided unless absolutely desired.

The introduction of library management also allows for some interesting features on a multi-user system. You can now subscribe to or directly inherit a collection from another user (or simply another location on disk).

**A word of caution:** using these features requires that you trust the other users on your system not do to nasty things. Collections are stored as a shell script containing a command which recreates a collection as a Bash associative array. A collection file could be tampered with and get you to execute anything arbitrarily. Theoretically, this should be no more dangerous that using scripts produced by another user on your system, yet you are much less likely to ever look at the contents of the files storing a collection than any other shell scripts. Use at your own risk.

#### Inheriting a collection

Inheriting a collection means that you have a symlink to the original collection and will receive updates to it as soon as they are made. This also means that, should you have group write permission to the inherited collection, you, and other users in the same group, can collaborate on the same collection to share useful paths. There is, however, no mutex, so it is best to communicate with others when updating the bookmarks in that collection.

#### Subscribing to a collection

When you subscribe to a collection, you have a local copy of it that does not update until manually specified. This is useful if you are concerned about the owner changing things under you. When shown in the list of collections, its *Meta* column will specify how outdated your copy is. Note that this is based on the modification time of the symlink pointing to the original collection. Whether you are missing out on any updates is not taken into account. Note that since you have your own local copy, you may modify it as desired, but those modifications will be lost when you decide to update the subscription.

## Advanced configuration

Immediately following the license text at the top of paths.bash, you will find a "user customization" section. These present the user with the ability to change where the path database is stored, what the default bookmark is called, and the aliases for the four primary functions. You may modify the alias declarations to your liking without breaking the script or any tab-completions.

### The default bookmark

The default bookmark can be changed, but never deleted. It is not tied to any collection. The idea behind it is to store a temporary bookmark that can be easily used at a later time or in another instance of your shell. Since bookmarked paths are immediately stored on disk, you can subsequently access the default bookmark (and any other bookmarks) in another shell. This is useful if you want another terminal open to the same directory and the cd command would be tedious to write. Using the default bookmark is explained in the help text for sp and gp.

You can rename the bookmark used to reference the default bookmark by changing the value of `_PATHS_DEFAULT_BM_NAME` in the script. Be careful that you do not shadow-delete the name of an existing bookmark in any of your collections. If there is a collision between the default bookmark name and that of one stored in a collection, the default bookmark will take precedence and no warning will be printed.

### Path Library

You can configure the location and name of the directory storing your bookmarks by changing the value of the `_PATHS_LIBRARY` environment variable, which is set by the script.

### Aliases

The real names of the functions are illustrated in the help text for each function. The user should utilize a convenient set of aliases to interact with these functions. This layer of indirection aims to maintain a naming scheme that is easily updatable and unlikely to need widespread refactoring. For example, there are internal uses of `_PATHS_PP`, so by utilizing the non-aliased name in scripts and functions, the functionality can be almost guaranteed.

If you want to change an alias, update the appropriate "value" in the `_PATHS_FUNC_ALIASES` associative array mapping.

### Environment

All environment variables and functions defined by this script are prefixed with `_PATHS_`.

There are two environment variables used by this script:
* `_PATHS_LIBRARY`
* `_PATHS_STATE_FILE`

The two-character function names used to interface with the path database storing your bookmarks are aliases to the actual functions.

Note that the environment is briefly polluted with an associative array called `_PATHS_FUNC_ALIASES` to set up the aliasing and a variable called `_PATHS_DEFAULT_BM_NAME` to configure the name of the default bookmark. These are unset by the time paths.bash is fully sourced.

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

### Collections

You need not concern yourself with collections if you prefer your bookmarks to be maximally accessible or have a simple set of bookmarks. A default collection is created and activated if no collections exist. This functionality should match that of paths.bash v3.x.x. The addition of multiple collections allows you to better organize and manage bookmarks. Collections of bookmarks are not simply for organization. There are three types, outlined below:
1. normal collections
    - nothing special here
    - just a file
2. inherited collections
    - these allow you to live-subscribe to a collection stored outside of your library using a new collection name that you specify
    - this is a symlink to the actual collection file
    - if you have write permissions to the linked file, you can edit this
3. subscribed collections
    - these are copied into your library and a `.src` file is created to track the origin and update time
    - you must manually update these using `ml -u`
    - the `.src` file is a symlink to the original collection
    - you can technically modify your copy, but it will be entirely overwritten upon update

**A word of caution:** I'll reiterate, since all collections are just a Bash script containing a variable declaration, they are sourced or eval'd when a collection needs to be loaded. This means that by subscribing to or inheriting a collection with write permissions belonging to a user other than your own, you run the risk of executing an arbitrary script from a bad actor if that person is another user on your system or has compromised said user. The inheritance and subscription features are designed for sharing collections on a multi-user system, but the security risks are there.

### Importing and exporting collections

There is no built-in feature to import or export collections, but you can easily do this by copying the desired `*.collection.sh` files to a new location or library. These files are named according to the collection they store and can be copied and inserted into a library without risk, so long as the default bookmark name is the same between the two relevant libraries.

### Utilizing functions

Creating a function-based bookmark is rather simple:
1. Define your function in your current shell
2. Create the bookmark using the following command in the same shell:
```
sp -f <function name> <bookmark name>
```

`paths.bash` will store the function definition internally, so the function need not exist in the user's environment to be utilized after storage, nor would the parent scope definition be used if it did. In fact, utilizing a function-based bookmark should not pollute the user's environment as it is defined and called within a subshell during bookmark resolution.

Below is an example function I use regularly to anchor my navigation within a "workspace" (a programmatically-initialized directory containing several git repos and somewhat deep directory hierarchies) by finding the workspace's WORKSPACE file (which resides at its root). Note that it returns in an error state if it does not find what it is looking for. `paths.bash` will check this return code and use it to determine if something went wrong during the function call. Any function utilized by `paths.bash` as a bookmark should return a real file path that is (preferably) a fully resolved path relative to root (/).


```
find_ws () {
(
    until [[ -e WORKSPACE ]]; do
        [[ $(pwd) == / ]] && return 1;
        \cd ..
    done
    pwd
)
}
```

This function is then stored into a bookmark which refers to the local workspace (that the shell's working directory is within):

```
sp -f find_ws local_ws
```

The 'local_ws' bookmark can then be used as the root bookmark for several relative bookmarks that point to useful areas within a workspace. These relative bookmarks would behave dynamically and can be used to navigate whatever workspace the user is currently within.

It is also noteworthy that `$bookmark_name` is a variable accessible to the function during its call. This is the name of the bookmark it is stored in. This is useful if you want to store the same function in different bookmarks and have it modify its behavior accordingly, such as using that bookmark name as a component of a path it constructs.

## Miscellaneous info

At time of writing, I do not have a formal way of testing this, so please keep an eye out for bugs and raise an issue if appropriate. I use this tool on a daily basis at my workplace, as do a number of my coworkers, so expect this utility to be maintained and slowly improved over time.

## License

See the associated LICENSE file in the repo. The licence is also duplicated inside paths.bash.
