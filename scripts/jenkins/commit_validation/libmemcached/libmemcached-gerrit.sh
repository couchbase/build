#!/bin/bash
#
# run by jenkins job 'libmemcached-gerrit'
#
#
#
# triggered on Patchset Creation of repo: libmemcached

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard

echo ============================================ update memcached
pushd libmemcached 2>&1 > /dev/null
git fetch ssh://review.couchbase.org:29418/libmemcached $GERRIT_REFSPEC && git checkout FETCH_HEAD

echo ============================================ make
popd 2>&1 > /dev/null
make -j4 all install
echo ============================================ make simple-test
cd testrunner
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true

echo ============================================ `date`
