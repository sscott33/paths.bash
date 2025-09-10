#!/usr/bin/env bash

SCRIPT_PATH=$(readlink -e "$BASH_SOURCE")
SCRIPT_DIR=${SCRIPT_PATH%/*}

OLD_HOME=$HOME
HOME=$SCRIPT_DIR
export HOME OLD_HOME

bash --rcfile <(cat <<EOF
    . "$SCRIPT_DIR/../paths.bash"
    HOME=$OLD_HOME
    export HOME
EOF
)
