#!/bin/bash
#          
#          run by jenkins job 'testrunner-gerrit-master.sh'
#          
#          with no paramters
#          
#          triggered on Patchset Creation of repo: testrunner branch: master

source ~jenkins/.bash_profile
set -e

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

ulimit -a
rm -rf testrunner/cluster_run.log
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard
cd testrunner
git reset --hard HEAD
git fetch ssh://review.couchbase.org:29418/testrunner $GERRIT_REFSPEC && git checkout FETCH_HEAD
cd ..
make -j8
cd testrunner
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
zip cluster_run_log cluster_run.log
echo ============================================ `date`
