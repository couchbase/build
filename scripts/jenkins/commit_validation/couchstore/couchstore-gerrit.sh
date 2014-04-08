#!/bin/bash
#
#          run by jenkins job:  couchstore-gerrit-master
#                               couchstore-gerrit-300
#                               couchstore-gerrit-251
#
#          use "--legacy" parameter for couchstore-gerrit-251
#
#          triggered on Patchset Creation of repo: couchstore

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard


echo ============================================ update couchstore

pushd couchstore  2>&1 > /dev/null
git fetch ssh://review.couchbase.org:29418/couchstore $GERRIT_REFSPEC && git checkout FETCH_HEAD

echo ============================================ make
popd                    2>&1 > /dev/null
make -j4 all install || (make -j1 && false)

if [ -d build/couchstore ]
then
  pushd build/couchstore 2>&1 > /dev/null
else
  pushd couchstore 2>&1 > /dev/null
fi

make test
popd 2>&1 > /dev/null

echo ============================================ make simple-test
cd testrunner
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true

echo ============================================ `date`
