#!/bin/bash -ex

# prepare for CBD-1932 - [CX] Encapsulate CBAS build under 'cbas' not 'asterixdb'
if [ -e "${WORKSPACE}/cbas" ]; then
  cd "${WORKSPACE}/cbas"
else
  cd "${WORKSPACE}/asterixdb"
fi
# hardwire the version for DP
mvn -B -f asterixdb/asterix-opt/pom.xml versions:set -DnewVersion=1.0.0-DP1
mvn -B clean install -DskipTests -Pcb-build
mv asterixdb/asterix-opt/installer/target/*.zip ${WORKSPACE}
