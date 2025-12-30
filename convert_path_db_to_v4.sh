#!/usr/bin/env bash

if [[ -z $1 || -z $2 || -z $3 ]]; then
    echo "Usage: $0 <old_paths.bash_script> <v4_paths.bash_script> <migrated_collection_name>"
    echo
    echo "This script migragtes a pre-v4.0.0 path database to the new multi-collection library format. The migrated bookmarks"
    echo "will be stored in a user specified collection. Note that this script will overwrite an existing collection of the same"
    echo "name without confirming."
    exit 1
fi

old_script=$1
new_script=$2
migrated_coll_name=$3

error=false
for s in old_script new_script; do
    [[ -e ${!s} ]] || { error=true; echo >&2 "Error: script '${!s}' not found"; }
done

$error && exit 1


# source old script
. "$old_script"

# store default bookmark name
default_bookmark_name=$_PATHS_DEFAULT_BM_NAME

# load old db
. "$_PATHS_PATH_DB_FILE"

# store old default bookmark and unset
default_bookmark_value=${path_db[$default_bookmark_name]}
unset "path_db[$default_bookmark_name]"

# source new script
. "$new_script"

# use save features to write default bookmark to state_db
eval "$(_PATHS_LOAD_STATE)"
state_db[default_bookmark_name]=$default_bookmark_name
state_db[default_bookmark_value]=$default_bookmark_value

_PATHS_SAVE_STATE

# save migrated collection using user-provided name
_PATHS_SAVE_DB "$migrated_coll_name"
