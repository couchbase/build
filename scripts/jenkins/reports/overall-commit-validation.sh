#!/bin/bash

#
#          run by jenkins job:  overall-commit-validation
#
#
#


STARTTIME=$(date +%s)

if [[ -e ${WORKSPACE}/build ]]  ;  then  rm -rf ${WORKSPACE}/build ; fi

echo git clone http://github.com/couchbase/build.git ${WORKSPACE}/build
     git clone http://github.com/couchbase/build.git ${WORKSPACE}/build

${WORKSPACE}/build/scripts/jenkins/commit_validation/couchdb/couchdb-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/couchdb/couchdb-gerrit-views-pre-merge.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/couchdb/couchdb-gerrit-views.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/couchstore/couchstore-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/ep-engine/ep-engine-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/ep-engine/ep-unit-tests.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/ns_server/ns_server-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/testrunner/testrunner-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/healthchecker/healthchecker-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/libmemcached/libmemcached-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/memcached/memcached-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/couchbase-cli/couchbase-cli-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/platform/platform-gerrit.sh

## Calculate elapsed time

ENDTIME=$(date +%s)

dt=$(($ENDTIME - $STARTTIME))

echo "It takes $(($ENDTIME - $STARTTIME)) seconds to complete this task.../n"

ds=$((dt % 60))
dm=$(((dt / 60) % 60))
dh=$((dt / 3600))
printf '%d:%02d:%02d' $dh $dm $ds



