#!/bin/bash
#
#          run by jenkins job 'couchdb-gerrit-views-master'
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

echo ============================================ update couchdb
pushd couchdb	2>&1 > /dev/null
git fetch ssh://review.couchbase.org:29418/couchdb $GERRIT_REFSPEC && git checkout FETCH_HEAD

echo ============================================ make
popd			2>&1 > /dev/null
make -j4 all install

cd testrunner
scripts/start_cluster_and_run_tests.sh b/resources/dev-single-node.ini conf/view-conf/py-viewmerge.conf
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
sleep 30
scripts/start_cluster_and_run_tests.sh b/resources/dev-4-nodes.ini conf/view-conf/py-viewmerge.conf
#make test-viewmerge SLEEP_TIME=30


echo ============================================ `date`
