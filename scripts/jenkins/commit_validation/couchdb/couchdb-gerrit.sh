#!/bin/bash
#          
#          run by jenkins job:  couchdb-gerrit-master
#                               
#                               
#          
#          with no paramters
#          
#          triggered on Patchset Creation of repo: couchdb

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort
  
echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard


echo ============================================ update couchdb
pushd couchdb     2>&1 > /dev/null
git fetch ssh://review.couchbase.org:29418/couchdb $GERRIT_REFSPEC && git checkout FETCH_HEAD
popd              2>&1 > /dev/null

echo ============================================ make
make -j4 || (make -j1 && false)

echo ============================================ make check
pushd couchdb     2>&1 > /dev/null

cpulimit -e 'beam.smp' -l 50 &
CPULIMIT_PID=$!
PATH=$PATH:${WORKSPACE}/cmake/couchstore   make check
kill $CPULIMIT_PID || true

popd              2>&1 > /dev/null

# echo ============================================ make simple-test
# pushd testrunner  2>&1 > /dev/null
# make simple-test
# popd              2>&1 > /dev/null

sudo killall -9 beam.smp epmd memcached python >/dev/null || true

echo ============================================ `date`
