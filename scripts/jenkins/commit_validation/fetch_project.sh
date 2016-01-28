#!/bin/sh

# Fetches a project by project name, path and Git ref
# This script is normally used in conjunction with allcommits.py:
# ./allcommits.py <change-id>|xargs -n 3 ./fetchproject.sh

set -x

PROJECT=$1
PROJECT_PATH=$2
REFSPEC=$3

if [ -z "$GERRIT_HOST" ]; then
    echo "Error: Required environment variable 'GERRIT_HOST' not set."
    exit 1
fi
if [ -z "$GERRIT_PORT" ]; then
    echo "Error: Required environment variable 'GERRIT_PORT' not set."
    exit 2
fi

cd $PROJECT_PATH
git reset --hard HEAD
git fetch ssh://$GERRIT_HOST:$GERRIT_PORT/$PROJECT $REFSPEC
git checkout FETCH_HEAD
cd ..
