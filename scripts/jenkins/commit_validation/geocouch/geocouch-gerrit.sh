#!/bin/bash
#
#          run by jenkins job 'geocouch-gerrit-master'
#
#          with no paramters
#
#          triggered on Patchset Creation of repo: geocouch branch: master


source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard

echo ============================================ update geocouch
cd geocouch
git fetch ssh://review.couchbase.org:29418/geocouch $GERRIT_REFSPEC && git checkout FETCH_HEAD

echo ============================================ make
cd ..
make -j4 all install
echo ============================================ make simple-test
cd testrunner
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
sleep 30
scripts/start_cluster_and_run_tests.sh b/resources/dev-4-nodes.ini conf/py-viewmerge.conf

echo ============================================ `date`
