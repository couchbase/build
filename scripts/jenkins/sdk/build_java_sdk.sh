#!/bin/bash

CORE_SHA=$1
CLIENT_SHA=$2

git clone git://github.com/couchbase/couchbase-jvm-core.git
if [ -n "${CORE_SHA}" ]
then
    pushd ${WORKSPACE}/couchbase-jvm-core && git checkout ${CORE_SHA} && popd
fi

git clone git://github.com/couchbase/couchbase-java-client.git
if [ -n "${CLIENT_SHA}" ]
then
    pushd  ${WORKSPACE}/couchbase-java-client && git checkout ${CLIENT_SHA} && popd
fi

cd ${WORKSPACE}/couchbase-jvm-core
mvn clean install -DskipTests=true

cd ${WORKSPACE}/couchbase-java-client
mvn clean install -DskipTests=true
