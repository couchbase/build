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

cat <<EOF
============================================
===                `date "+%H:%M:%S"`              ===
============================================
EOF
env | grep -iv password | grep -iv passwd | sort

cat <<EOF
============================================
===               clean                  ===
============================================
EOF
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard
repo forall -c "git clean -xfd"
rm -f ./testrunner/cluster_run.log
df -h

cat <<EOF
============================================
===            update CouchDB            ===
============================================
EOF
pushd couchdb 2>&1 > /dev/null
git fetch ssh://review.couchbase.org:29418/couchdb $GERRIT_REFSPEC && git checkout FETCH_HEAD
popd 2>&1 > /dev/null

cat <<EOF
============================================
===               Build                  ===
============================================
EOF
make -j4 all install

cat <<EOF
============================================
===         Run end to end tests         ===
============================================
EOF
cd testrunner
scripts/start_cluster_and_run_tests.sh b/resources/dev-single-node.ini conf/view-conf/py-view-pre-merge.conf
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
sleep 30
scripts/start_cluster_and_run_tests.sh b/resources/dev-4-nodes.ini conf/view-conf/py-view-pre-merge.conf
#make test-viewmerge SLEEP_TIME=30

cat <<EOF
============================================
===                `date "+%H:%M:%S"`              ===
============================================
EOF
