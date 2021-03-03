#!/bin/bash

PRODUCT=$1
RELEASE_VERSION=$2
PUBLISH_URL=$3

mkdir -p  ${WORKSPACE}/tmp
pushd ${WORKSPACE}/tmp
find ${WORKSPACE}/caches -type f -name "couchbase*.aar"  |  xargs jar xvf

# Error if grep returns 0 for CE packages
for i in DatabaseEndpoint.class EncryptionKey.class; do
    jar tvf classes.jar | grep $i
     if [ $? == 0 ] && [ "${PRODUCT}" == 'couchbase-lite-android' ]; then
        echo "Error, Encryption keys found CE package"
        exit 1
    fi
done

popd
