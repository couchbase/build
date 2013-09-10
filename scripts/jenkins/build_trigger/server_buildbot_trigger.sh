#!/bin/bash
#          
#          jenkins monitors changes in files pointed to by server manifest
#          and triggers buildbot repo-* job to build on all platforms

DATA_DIR=/var/lib/jenkins/data/buildbot_trigger

URL_ROOT=http://builds.hq.northscale.net:8010
USERPASS='username=couchbase.build\&passwd=couchbase.build.password'

BRANCH=master

if [[ ${1} ]] ; then BRANCH=$1 ; shift ; fi

MFST_PRE=${DATA_DIR}/manifest.${BRANCH}.prev
MFST_NOW=${DATA_DIR}/manifest.${BRANCH}.now

BUILDER=repo-couchbase-${BRANCH}-builder

if [[ ! -f ${MFST_PRE} ]]
    then
    echo ......launching FIRST build ${BUILDER}
    echo ......curl ${URL_ROOT}/builders/${BUILDER}/force?forcescheduler=all_repo_builders\&${USERPASS}
    curl ${URL_ROOT}/builders/${BUILDER}/force?forcescheduler=all_repo_builders\&${USERPASS}
    repo manifest -r  > ${MFST_PRE}
    exit 0
fi

repo manifest -r  > ${MFST_NOW}

manifest_diff=`diff ${MFST_NOW} ${MFST_PRE} | grep "project name" | grep -v testrunner`

if [[ "x$manifest_diff" != "x" ]]
  then
    echo ......launching NEW build ${BUILDER}
    echo ......curl ${URL_ROOT}/builders/${BUILDER}/force?forcescheduler=all_repo_builders\&${USERPASS}
    curl ${URL_ROOT}/builders/${BUILDER}/force?forcescheduler=all_repo_builders\&${USERPASS}
    repo manifest -r  > ${MFST_PRE}
  else
    echo ">>> No relevant changes"
fi
