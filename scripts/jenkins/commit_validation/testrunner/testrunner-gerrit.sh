#!/bin/bash
#          
#          run by jenkins job 'testrunner-gerrit-master.sh'
#          
#          with no paramters
#          
#          triggered on Patchset Creation of repo: testrunner branch: master

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
rm -rf testrunner/cluster_run.log
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard
repo forall -c "git clean -xfd"

echo ============================================ update testrunner
cd testrunner
git reset --hard HEAD
git fetch ssh://review.couchbase.org:29418/testrunner $GERRIT_REFSPEC && git checkout FETCH_HEAD

echo ============================================ make
cd ..
make
echo ============================================ make simple-test
cd testrunner
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
zip cluster_run_log cluster_run.log
echo ============================================ `date`
