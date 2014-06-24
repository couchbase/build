#!/bin/bash
#
#          run by jenkins job 'ep-unit-tests-master.sh'
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
make clean-xfd-hard

cat <<EOF
============================================
===               Build                  ===
============================================
EOF
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
if [ -d build/ep-engine ]
then
   pushd build/ep-engine 2>&1 > /dev/null
else
   pushd ep-engine 2>&1 > /dev/null
fi

make test

if [ -f Makefile.am ]
then
  make engine-tests
fi

popd 2>&1 > /dev/null

cat <<EOF
============================================
===                `date "+%H:%M:%S"`              ===
============================================
EOF

## Print log file

if [ -f ${WORKSPACE}/build/ep-engine/Testing/Temporary/LastTest.log ]
then
  cat ${WORKSPACE}/build/ep-engine/Testing/Temporary/LastTest.log
fi

## Cleanup .repo directory

if [ -d ${WORKSPACE}/.repo ]
then
  rm -rf ${WORKSPACE}/.repo
fi
