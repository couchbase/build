#!/bin/sh

set -e
set -x

# CCACHE is good - use it if available.
export PATH=/usr/lib/ccache:$PATH


cat <<EOF
============================================
===              environment             ===
============================================
EOF
ulimit -a
env | grep -iv password | grep -iv passwd | sort

cat <<EOF
============================================
===                 clean                ===
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
./build-scripts/scripts/jenkins/commit_validation/alldependencies.py $GERRIT_PATCHSET_REVISION|\
    xargs -n 3 ./build-scripts/scripts/jenkins/commit_validation/fetch_project.sh

cat <<EOF
============================================
===                 build                ===
============================================
EOF
make -j4

cat <<EOF
============================================
===  run dialyzer and couchdb unit tests ===
============================================
EOF
# Copy couchdb.plt from /tmp to ${WORKSPACE}/build/couchdb to gain build time
if [ -f /tmp/couchdb.plt ]
then
    cp /tmp/couchdb.plt ${WORKSPACE}/build/couchdb/
fi

cd build/couchdb
make check
cd ../..

# Copy couchdb.plt from ${WORKSPACE}/build/couchdb back to /tmp so it
# can be restored
if [ -f ${WORKSPACE}/build/couchdb/couchdb.plt ]
then
    cp ${WORKSPACE}/build/couchdb/couchdb.plt /tmp/
fi

cat <<EOF
============================================
===           make simple-test           ===
============================================
EOF
cd testrunner
make simple-test
cd ..
