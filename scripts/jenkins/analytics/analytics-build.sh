#!/bin/bash -ex

cd "${WORKSPACE}/asterixdb"
mvn clean install -DskipTests
mv asterixdb/asterix-installer/target/*.zip ${WORKSPACE}

