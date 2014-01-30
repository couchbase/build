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
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard


echo ============================================ update cli
cd couchbase-cli
git fetch ssh://review.couchbase.org:29418/couchbase-cli $GERRIT_REFSPEC && git checkout FETCH_HEAD

echo ============================================ make
cd ..
make -j4

echo ============================================ make simple-test
cd testrunner
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true

echo ============================================ `date`
