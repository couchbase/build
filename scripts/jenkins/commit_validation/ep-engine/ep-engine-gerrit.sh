#!/bin/bash
#
#          run by jenkins job 'ep-engine-gerrit-master.sh'
#
#
#          use "--legacy" parameter for ep-engine-gerrit-251
#          triggered on Patchset Creation of repo: ep-engine branch: master

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

cat <<EOF
============================================
===          update ep-engine            ===
============================================
EOF
pushd ep-engine 2>&1 > /dev/null
git fetch ssh://review.couchbase.org:29418/ep-engine $GERRIT_REFSPEC && git checkout FETCH_HEAD
popd 2>&1 > /dev/null

cat <<EOF
============================================
===               Build                  ===
============================================
EOF
make -j4 all

if [ -d build ]
then
   make install
fi

cat <<EOF
============================================
===         Run end to end tests         ===
============================================
EOF
cd testrunner
make simple-test

cat <<EOF
============================================
===                `date "+%H:%M:%S"`              ===
============================================
EOF
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
