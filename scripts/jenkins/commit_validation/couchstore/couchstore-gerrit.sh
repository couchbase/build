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
===         update couchstore            ===
============================================
EOF
pushd couchstore  2>&1 > /dev/null
git fetch ssh://review.couchbase.org:29418/couchstore $GERRIT_REFSPEC && git checkout FETCH_HEAD

popd 2>&1 > /dev/null

cat <<EOF
============================================
===               Build                  ===
============================================
EOF
make -j4 all install || (make -j1 && false)

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
