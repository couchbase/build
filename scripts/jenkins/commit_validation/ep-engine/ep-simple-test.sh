#!/bin/bash
#
#          run by jenkins job 'ep-simple-test-master.sh'
#
#          with no paramters
#
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

## Cleanup .repo directory

if [ -d ${WORKSPACE}/.repo ]
then
  rm -rf ${WORKSPACE}/.repo
fi
