#!/bin/bash
#          
#          run by jenkins job 'couchdb-gerrit-upr'
#          
#          with no paramters
#          
#          triggered on Patchset Creation of repo: couchdb branch: master

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
sudo killal -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard
repo forall -c "git clean -xfd"

echo ============================================ update couchdb
cd couchdb
git fetch ssh://review.couchbase.org:29418/couchdb $GERRIT_REFSPEC && git checkout FETCH_HEAD
git log --pretty=oneline -n 10

echo ============================================ make
cd ..
make -j4 || (make -j1 && false)
cd couchdb

cpulimit -e 'beam.smp' -l 50 &
CPULIMIT_PID=$!

PATH=$PATH:${WORKSPACE}/install/bin   make check
kill $CPULIMIT_PID || true

echo ============================================ `date`
