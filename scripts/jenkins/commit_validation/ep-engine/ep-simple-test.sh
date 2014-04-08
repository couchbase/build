#!/bin/bash
#
#          run by jenkins job 'ep-simple-test-master.sh'
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
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard


echo ============================================ make
make all install
echo ============================================ make simple-test
cd testrunner
make simple-test

echo ============================================ `date`
