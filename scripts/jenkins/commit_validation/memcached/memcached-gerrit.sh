#!/bin/bash
#
# run by jenkins job 'memcached-gerrit'
#
#
# triggered on Patchset Creation of repo: memcached

# How many jobs to run in parallel by default?
PARALLELISM="${PARALLELISM:-8}"

source ~jenkins/.bash_profile
set -e

# CCACHE is good - use it if available.
export PATH=/usr/lib/ccache:$PATH

function echo_cmd {
    echo \# "$@"
    "$@"
}

cat <<EOF

============================================
===            environment               ===
============================================
EOF
ulimit -a
echo ""
env | grep -iv password | grep -iv passwd | sort

cat <<EOF

============================================
===               clean                  ===
============================================
EOF
echo_cmd make clean-xfd-hard

cat <<EOF

============================================
===          update memcached            ===
============================================
EOF
pushd memcached 2>&1 > /dev/null
echo_cmd git fetch ssh://review.couchbase.org:29418/memcached $GERRIT_REFSPEC
echo_cmd git checkout FETCH_HEAD
popd 2>&1 > /dev/null

cat <<EOF

============================================
===               Build                  ===
============================================
EOF
echo_cmd make -j${PARALLELISM}

cat <<EOF

============================================
===          Run unit tests              ===
============================================
EOF
if [ -d build/memcached ]
then
   TEST_DIR=build/memcached
else
   TEST_DIR=memcached
fi
pushd ${TEST_DIR} 2>&1 > /dev/null
# -j${PARALLELISM} : Run tests in parallel.
# -T Test   : Generate XML output file of test results.
# "|| true" : Needed to ensure that xUnit scanner is run even if one or more
#             tests fail.
echo_cmd make test ARGS="-j${PARALLELISM} --output-on-failure --no-compress-output -T Test" || true
popd 2>&1 > /dev/null
