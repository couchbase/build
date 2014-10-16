#!/bin/bash

# run by jenkins job 'geocouch-gerrit-master'
# with no paramters
# triggered on Patchset Creation of repo: geocouch branch: master

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date --iso-8601=seconds`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean \
`date --iso-8601=seconds`
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard

echo ============================================ update geocouch \
`date --iso-8601=seconds`
cd geocouch
git fetch ssh://review.couchbase.org:29418/geocouch $GERRIT_REFSPEC && \
git checkout FETCH_HEAD
cd ..

echo ============================================ make \
`date --iso-8601=seconds`
make -j4

echo ============================================ run dialyzer \
`date --iso-8601=seconds`
# Copy geocouch.plt from /tmp to ${WORKSPACE}/build/geocouch to gain build time
if [ -f /tmp/geocouch.plt ]
then
    cp /tmp/geocouch.plt ${WORKSPACE}/build/geocouch/
fi

cd build
make geocouch-dialyzer
cd ..

# Copy geocouch.plt from ${WORKSPACE}/build/geocouch back to /tmp so it
# can be restored
if [ -f ${WORKSPACE}/build/geocouch/geocouch.plt ]
then
    cp ${WORKSPACE}/build/geocouch/geocouch.plt /tmp/
fi

echo ============================================ run geocouch unit tests \
`date --iso-8601=seconds`
make geocouch-build-for-testing -j4
cd build/geocouch-for-tests
make test
cd ../../

echo ============================================ make simple-test \
`date --iso-8601=seconds`
cd testrunner
make simple-test
cd ..

echo ============================================ `date --iso-8601=seconds`
