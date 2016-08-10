#!/bin/bash -ex

cd "${WORKSPACE}/asterixdb"
mvn clean install -DskipTests
mv asterixdb/asterix-opt/installer/target/*.zip ${WORKSPACE}
