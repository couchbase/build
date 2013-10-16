#!/bin/bash
#          
#          jenkins monitors changes in files pointed to by server manifest
#          and triggers buildbot repo-* job to build on all platforms

CURL=/usr/bin/curl
DATA_DIR=/var/lib/jenkins/data/buildbot_trigger

URL_ROOT=http://builds.hq.northscale.net:8010
USERNAME='username=couchbase.build'
USERPASS='passwd=couchbase.build.password'

BRANCH=master

if [[ ${1} ]] ; then BRANCH=$1 ; shift ; fi

MFST_PRE=${WORKSPACE}/manifest.${BRANCH}.prev    #  put here by 'Copy To Slave Plugin'
MFST_NOW=${WORKSPACE}/manifest.${BRANCH}.now

BUILDER=repo-couchbase-${BRANCH}-builder

if [[ ! -f ${MFST_PRE} ]]
    then
    echo ......launching FIRST build ${BUILDER}
    echo ......${CURL} ${URL_ROOT}/builders/${BUILDER}/force?forcescheduler=all_repo_builders\&${USERNAME}\&${USERPASS}
    ${CURL} ${URL_ROOT}/builders/${BUILDER}/force?forcescheduler=all_repo_builders\&${USERNAME}\&${USERPASS}
    repo manifest -r  > ${MFST_PRE}
    exit 0
fi

repo manifest -r  > ${MFST_NOW}

manifest_diff=`diff ${MFST_NOW} ${MFST_PRE} | grep "project name" | grep -v testrunner`

if [[ "x$manifest_diff" != "x" ]]
  then
    echo ......launching NEW build ${BUILDER}
    echo ......${CURL} ${URL_ROOT}/builders/${BUILDER}/force?forcescheduler=all_repo_builders\&${USERNAME}\&${USERPASS}
    ${CURL} ${URL_ROOT}/builders/${BUILDER}/force?forcescheduler=all_repo_builders\&${USERNAME}\&${USERPASS}
    repo manifest -r  > ${MFST_PRE}
  else
    echo ">>> No relevant changes"
fi
