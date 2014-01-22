#!/bin/bash
#          
#          run by jenkins job 'ep-unit-tests-master.sh'
#          
#          with no paramters
#          
#          triggered on Patchset Creation of repo: ep-engine branch: master

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
make clean-xfd-hard

echo ============================================ update ep-engine
pushd libmemcached     > /dev/null
config/autorun.sh
./configure
make
popd                   > /dev/null
echo ===============================================================

pushd cmake/couchstore > /dev/null
config/autorun.sh
./configure
make
popd                   > /dev/null
echo ===============================================================

pushd cmake/ep-engine  > /dev/null
config/autorun.sh
./configure --with-memcached=../memcached LDFLAGS=-L$WORKSPACE/couchstore/.libs CPPFLAGS=-I$WORKSPACE/couchstore/include
LD_LIBRARY_PATH=/home/jenkins/jenkins/workspace/ep-unit-tests-master/install/lib make test
popd                   > /dev/null

echo ============================================ `date`
