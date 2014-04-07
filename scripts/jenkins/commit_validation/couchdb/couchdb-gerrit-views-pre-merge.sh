#!/bin/bash
#
#          run by jenkins job 'couchdb-gerrit-views-pre-merge-master'
#
#          with no paramters
#
#          triggered on Patchset Creation of repo: couchdb branch: master

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard
repo forall -c "git clean -xfd"
rm -f ./testrunner/cluster_run.log
df -h

echo ============================================ update couchdb
pushd couchdb
git fetch ssh://review.couchbase.org:29418/couchdb $GERRIT_REFSPEC && git checkout FETCH_HEAD

echo ============================================ make
popd
make -j4

cd testrunner
scripts/start_cluster_and_run_tests.sh b/resources/dev-single-node.ini conf/view-conf/py-view-pre-merge.conf
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
sleep 30
scripts/start_cluster_and_run_tests.sh b/resources/dev-4-nodes.ini conf/view-conf/py-view-pre-merge.conf
#make test-viewmerge SLEEP_TIME=30


echo ============================================ `date`
