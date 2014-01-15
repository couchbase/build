#!/bin/bash
#          
#          run by jenkins job 'cli-gerrit.sh'
#          
#          with no paramters
#          
#          triggered on Patchset Creation of repo: testrunner branch: master

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ update cli
cd couchbase-cli
git reset --hard HEAD
git fetch ssh://review.couchbase.org:29418/couchbase-cli $GERRIT_REFSPEC && git checkout FETCH_HEAD

sudo easy_install --upgrade nose
nosetests -v

echo ============================================ `date`
