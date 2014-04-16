#!/bin/bash

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

${WORKSPACE}/build/scripts/jenkins/commit_validation/healthchecker/healthchecker-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/libmemcached/libmemcached-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/memcached/memcached-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/couchbase-cli/couchbase-cli-gerrit.sh

${WORKSPACE}/build/scripts/jenkins/commit_validation/platform/platform-gerrit.sh


