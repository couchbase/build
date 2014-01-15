#!/bin/bash
#          
#          run by jenkins job 'couchstore-gerrit-master'
#          
#          with no paramters
#          
#          triggered on Patchset Creation of repo: testrunner branch: master

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean

make clean-xfd-hard
cd cmake/couchstore
git fetch ssh://review.couchbase.org:29418/couchstore $GERRIT_REFSPEC && git checkout FETCH_HEAD

echo =========================================== make
cd ../..
make
cd cmake/couchstore
make test

echo ============================================ `date`
