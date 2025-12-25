#!/usr/bin/env bash


if [[ -z $1 || -z $2 || -z $3 ]]; then
    echo "Usage: $0 <old paths.bash script> <v4 paths.bash script> <migrated collection name>"
    exit 1
fi

old_script=$1
new_script=$2
migrated_coll_name=$3


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
