#!/bin/bash -ex

cd "${WORKSPACE}/asterixdb"
# hardwire the version for DP
mvn -f asterixdb/asterix-opt/pom.xml versions:set -DnewVersion=1.0.0-DP1
mvn clean install -DskipTests -Pcb-build
mv asterixdb/asterix-opt/installer/target/*.zip ${WORKSPACE}
