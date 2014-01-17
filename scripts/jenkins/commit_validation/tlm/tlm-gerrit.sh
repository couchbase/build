#!/bin/bash
#          
#          run by jenkins job 'tlm-gerrit-master'
#          
#          with no paramters
#          
#          triggered on Patchset Creation of repo: tlm branch: master

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard

echo ============================================ update tlm
cd tlm
git fetch ssh://review.couchbase.org:29418/tlm $GERRIT_REFSPEC && git checkout FETCH_HEAD

echo ============================================ make
cd ..
make -j4
echo ============================================ make simple-test
cd testrunner
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
sleep 30
scripts/start_cluster_and_run_tests.sh b/resources/dev-4-nodes.ini conf/py-viewmerge.conf 

echo ============================================ `date`
