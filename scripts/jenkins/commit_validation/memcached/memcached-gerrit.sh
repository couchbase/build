#!/bin/bash
#
# run by jenkins job 'memcached-gerrit'
#
#
# triggered on Patchset Creation of repo: memcached

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
===          update memcached            ===
============================================
EOF
pushd  memcached 2>&1 > /dev/null
git fetch ssh://review.couchbase.org:29418/memcached $GERRIT_REFSPEC && git checkout FETCH_HEAD

cat <<EOF
============================================
===               Build                  ===
============================================
EOF
popd 2>&1 > /dev/null
make all
if [ -d build ]
then
   make install
fi

cat <<EOF
============================================
===          Run unit tests              ===
============================================
EOF
if [ -d build/memcached ]
then
   pushd build/memcached 2>&1 > /dev/null
else
   pushd memcached 2>&1 > /dev/null
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
