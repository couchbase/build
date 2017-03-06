#!/bin/bash -ex

cd "${WORKSPACE}/cbas"

mvn -B -f asterixdb/asterix-opt/pom.xml versions:set -DnewVersion=1.0.0-DP2

# build
mvn -B clean install -DskipTests -Pcb-build

# move the installer where the jenkins job expects it
mv asterixdb/asterix-opt/installer/target/*.zip ${WORKSPACE}
