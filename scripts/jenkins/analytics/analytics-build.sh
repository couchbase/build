#!/bin/bash -ex

cd "${WORKSPACE}/cbas"

# uncomment the following to hardwire the version for a release...
#mvn -B -f asterixdb/asterix-opt/pom.xml versions:set -DnewVersion=1.0.0-DP1

# build
mvn -B clean install -DskipTests -Pcb-build

# move the installer where the jenkins job expects it
mv asterixdb/asterix-opt/installer/target/*.zip ${WORKSPACE}
