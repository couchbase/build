#!/bin/bash
#
# run by jenkins job 'memcached-gerrit'
#
#
# triggered on Patchset Creation of repo: memcached

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard

echo ============================================ update memcached
pushd  memcached 2>&1 > /dev/null
git fetch ssh://review.couchbase.org:29418/memcached $GERRIT_REFSPEC && git checkout FETCH_HEAD

echo ============================================ make
popd 2>&1 > /dev/null
make all install

echo ============================================ run unit tests

if [ -d build/memcached ]
then
   pushd build/memcached 2>&1 > /dev/null
else
   pushd memcached 2>&1 > /dev/null
fi

make test
popd 2>&1 > /dev/null

echo ============================================ make simple-test
cd testrunner
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true

echo ============================================ `date`
