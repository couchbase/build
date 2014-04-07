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
make


echo ============================================ update ep-engine
pushd ep-engine    2>&1  >    /dev/null
make test
make engine-tests
popd                     2>&1  >    /dev/null

echo ============================================ `date`
