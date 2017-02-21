#!/bin/bash -e

# Clean old artifacts
workspace=`pwd`
rm -rf "${workspace}/artifacts"

# Check for new version of CBQ
CBQ_VER=${CBQ_VER-5.0.0}
CBQ_BUILDS=/latestbuilds/cbq/${CBQ_VER}

latest_cbq=`ls -rt "${CBQ_BUILDS}" | tail -1`
echo "Most recent CBQ build is ${CBQ_VER}-${latest_cbq}"
if [ -e "${CBQ_BUILDS}/${latest_cbq}/CBAS_TESTED" ]
then
  echo "Version already tested for CBAS, nothing to do"
  exit
fi

if [ ! -e ${CBQ_BUILDS}/${latest_cbq}/cbq-linux -o \
     ! -e ${CBQ_BUILDS}/${latest_cbq}/cbq-macos -o \
     ! -e ${CBQ_BUILDS}/${latest_cbq}/cbq-windows.exe ]
then
  echo "Some cbq binaries missing, will try again later"
  exit
fi

# Mark this version as (about to be) tested
touch "${CBQ_BUILDS}/${latest_cbq}/CBAS_TESTED"

echo "Copying CBQ for Linux"
cp "${CBQ_BUILDS}/${latest_cbq}/cbq-linux" cbq
chmod 755 cbq

# Obtain latest CBAS source
CBAS_VER=${CBAS_VER-1.0.0}
CBAS_BUILDS=/latestbuilds/analytics/${CBAS_VER}
latest_cbas=`cat "${CBAS_BUILDS}/latestBuildNumber"`
echo "Most recent CBAS build is ${CBAS_VER}-${latest_cbas}"

echo "Unpacking CBAS source..."
rm -rf cbas
mkdir cbas
cd cbas
tar xzf "${CBAS_BUILDS}/${latest_cbas}/analytics-${CBAS_VER}-${latest_cbas}-source.tar.gz"

# Build
echo "Building CBAS"
cd cbas
mvn -B install -DskipTests

# Test
echo "Testing CBQ interop"
cd asterixdb/asterix-opt/cbq-interop/cbq-test
mvn -B verify -Dcbq.exe.path="${workspace}/cbq"

# If we get here, all is well - archive this CBQ build
echo
echo "Success! Archiving CBQ ${CBQ_VER}-${latest_cbq}"
mkdir "${workspace}/artifacts"
cd "${CBQ_BUILDS}/${latest_cbq}"
cp cbq-linux cbq-macos "${workspace}/artifacts"
cp cbq-windows.exe "${workspace}/artifacts/cbq.exe"
chmod 755 "${workspace}/artifacts/cbq"*
cp *-manifest.xml "${workspace}/artifacts/cbq-manifest.xml"
cp *-properties.json "${workspace}/artifacts/cbq-properties.json"
cp *.properties "${workspace}/artifacts/cbq.properties"

