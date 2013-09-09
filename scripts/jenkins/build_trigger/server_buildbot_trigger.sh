#!/bin/bash

#          jenkins monitors changes in files pointed to by server manifest
#          and triggers buildbot repo-* job to build on all platforms

DATA_DIR=/var/lib/jenkins/data/buildbot_trigger
DATA_DIR=./TEST

BRANCH=master

if [[ ${1} ]] ; then BRANCH=$1 ; shift ; fi

MFST_PRE=${DATA_DIR}/manifest.${BRANCH}.prev
MFST_NOW=${DATA_DIR}/manifest.${BRANCH}.temp

BUILDER=repo-couchbase-${BRANCH}-builder

if [[ ! -f /tmp/manifest.master.prev ]]
    then
    echo curl "http://builds.hq.northscale.net:8010/builders/${BUILDER}/force?forcescheduler=all_repo_builders&username=couchbase.build&passwd=couchbase.build.password"
    repo manifest -r  > ${MFST_PRE}
    exit 0
fi

repo manifest -r  > ${MFST_NOW}

manifest_diff=`diff ${MFST_NOW} ${MFST_PRE} | grep "project name" | grep -v testrunner`

if [ "x$manifest_diff" != "x" ]; then
    echo curl "http://builds.hq.northscale.net:8010/builders/${BUILDER}/force?forcescheduler=all_repo_builders&username=couchbase.build&passwd=couchbase.build.password"
    repo manifest -r  > ${MFST_PRE}
else
    echo ">>> No relevant changes"
fi
