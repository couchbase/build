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
make all install


echo ============================================ update ep-engine

if [ -d build/ep-engine ]
then
   pushd build/ep-engine 2>&1 > /dev/null
else
   pushd ep-engine 2>&1 > /dev/null
fi

make test

if [ -f Makefile.am ]
then
  make engine-tests
fi

popd 2>&1 > /dev/null

echo ============================================ `date`
