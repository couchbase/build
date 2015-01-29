#!/bin/bash
#
#          run by jenkins job:  couchstore-gerrit-master
#                               couchstore-gerrit-300
#                               couchstore-gerrit-251
#
#          use "--legacy" parameter for couchstore-gerrit-251
#
#          triggered on Patchset Creation of repo: couchstore

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
===       update all projects with       ===
===          the same Change-Id          ===
============================================
EOF
pushd couchstore  2>&1 > /dev/null
./build-scripts/scripts/jenkins/commit_validation/alldependencies.py $GERRIT_PATCHSET_REVISION|\
    xargs -n 3 ./build-scripts/scripts/jenkins/commit_validation/fetch_project.sh

popd 2>&1 > /dev/null

cat <<EOF
============================================
===               Build                  ===
============================================
EOF
make -j4 all || (make -j1 && false)
if [ -d build ]
then
   make install
fi

cat <<EOF
============================================
===          Run unit tests              ===
============================================
EOF
if [ -d build/couchstore ]
then
  pushd build/couchstore 2>&1 > /dev/null
else
  pushd couchstore 2>&1 > /dev/null
fi

make test
popd 2>&1 > /dev/null

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

## Cleanup .repo directory

if [ -d ${WORKSPACE}/.repo ]
then
  rm -rf ${WORKSPACE}/.repo
fi
