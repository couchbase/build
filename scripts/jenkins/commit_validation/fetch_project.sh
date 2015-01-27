#!/bin/sh

# Fetches a project by project name, path and Git ref
# This script is normally used in conjunction with allcommits.py:
# ./allcommits.py <change-id>|xargs -n 3 ./fetchproject.sh

set -x

PROJECT=$1
PROJECT_PATH=$2
REFSPEC=$3

cd $PROJECT_PATH
git reset --hard HEAD
git fetch ssh://review.couchbase.org:29418/$PROJECT $REFSPEC
git checkout FETCH_HEAD
cd ..
