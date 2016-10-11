#!/bin/bash -ex

cd "${WORKSPACE}/asterixdb"
mvn clean install -DskipTests -Pcb-build
mv asterixdb/asterix-opt/installer/target/*.zip ${WORKSPACE}
