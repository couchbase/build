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
===   run py-view-pre-merge.conf tests   ===
============================================
EOF
cd testrunner
scripts/start_cluster_and_run_tests.sh b/resources/dev-single-node.ini conf/view-conf/py-view-pre-merge.conf
scripts/start_cluster_and_run_tests.sh b/resources/dev-4-nodes.ini conf/view-conf/py-view-pre-merge.conf
cd ..
