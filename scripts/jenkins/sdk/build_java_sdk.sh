#!/bin/bash

git clone git://github.com/couchbase/couchbase-jvm-core.git
git clone git://github.com/couchbase/couchbase-java-client.git

cd ${WORKSPACE}/couchbase-jvm-core
mvn clean install -DskipTests=true

cd ${WORKSPACE}/couchbase-java-client
mvn clean install -DskipTests=true
