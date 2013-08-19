#!/bin/bash


GITHUB=git://10.1.1.210

for PROJ in couchbase-java-client couchbase-ruby-client spymemcached
    do
    PROJ_DIR=./${PROJ}
    if [[ -d ${PROJ_DIR} ]] ; then rm -rf ${PROJ_DIR} ; mkdir ${PROJ_DIR} ; fi
    git clone ${GITHUB}/${PROJ}.git  ${PROJ_DIR}
    echo ---------------------------------------
done

DOC_DIR=./unified-docs
if [[ -d ${DOC_DIR} ]] ; then rm -rf ${DOC_DIR} ; mkdir ${DOC_DIR} ; fi

./build-java-unified-docs.sh
./build-ruby-docs.sh

javadoc -d ${DOC_DIR} \
    `find couchbase-java-client/src/main/java/com/couchbase/client -name "*.java"` \
    `find couchbase-ruby-client/src/main/java/com/couchbase/client -name "*.java"` \
    `find spymemcached/src/main/java/net/spy/memcached             -name "*.java"`
