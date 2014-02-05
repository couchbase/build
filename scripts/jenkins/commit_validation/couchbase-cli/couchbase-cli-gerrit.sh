#!/bin/bash
#          
#          run by jenkins job:  couchbase-cli-gerrit-master
#                               couchbase-cli-gerrit-300
#                               couchbase-cli-gerrit-250
#          
#          with no paramters
#          
#          triggered on Patchset Creation of repo: couchbase-cli

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort
  
echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python 2>&1 > /dev/null || true

make clean-xfd-hard

echo ============================================ update cli
git fetch ssh://review.couchbase.org:29418/couchbase-cli $GERRIT_REFSPEC && git checkout FETCH_HEAD
 
sudo easy_install --upgrade nose
nosetests -v

sudo killall -9 beam.smp epmd memcached python  2>&1 > /dev/null || true

echo ============================================ `date`

