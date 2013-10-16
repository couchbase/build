#!/bin/bash
#          
#          run by jenkins job 'build_cblite_android'
#          
#          with paramters used in this script:
#             
#             SYNCGATE_VERSION
#             
#          and with paramters passed on to downstream jobs:
#             
#             UPLOAD_ARTIFACTS        (boolean)
#             UPLOAD_VERSION_CBLITE
#             UPLOAD_VERSION_CBLITE_EKTORP
#             UPLOAD_VERSION_CBLITE_JAVASCRIPT
#             UPLOAD_MAVEN_REPO_URL
#             UPLOAD_USERNAME
#             UPLOAD_PASSWORD
#          
VERSION=1.0

source ~/.bash_profile
export DISPLAY=:0

PLATFORM=linux-amd64

AND_TARG=24
                #  "android-17"
AND_TARG=1
EMULATOR=cblite

AUT_DIR=${WORKSPACE}/app-under-test
if [[ -e ${AUT_DIR} ]] ; then rm -rf ${AUT_DIR} ; fi
mkdir -p ${AUT_DIR}/sync_gateway

       SYNCGATE_VRSN=${VERSION}-${SYNCGATE_VERSION}
export SYNCGATE_PATH=${AUT_DIR}/sync_gateway

DOWNLOAD=${AUT_DIR}/download
env | grep -iv password | sort ; echo ====================================

cd ${WORKSPACE}                ; echo ====================================
#--------------------------------------------  sync couchbase-lite-android

if [[ ! -d couchbase-lite-android ]] ; then git clone https://github.com/couchbase/couchbase-lite-android.git ; fi
cd couchbase-lite-android
git pull
git submodule init
git submodule update
git show --stat

cd ${WORKSPACE}                ; echo ====================================
#--------------------------------------------  sync cblite-tests

if [[ ! -d cblite-tests ]] ; then git clone https://github.com/couchbaselabs/cblite-tests.git ; fi
cd cblite-tests
git pull

cd ${WORKSPACE}                ; echo ====================================
#--------------------------------------------  install sync_gateway
rm   -rf ${DOWNLOAD}
mkdir -p ${DOWNLOAD}
pushd    ${DOWNLOAD} 2>&1 > /dev/null

ZIPFILE=sync_gateway_${SYNCGATE_VRSN}.zip
wget --no-verbose http://cbfs.hq.couchbase.com:8484/builds/${ZIPFILE}
STATUS=$?
if [[ ${STATUS} > 0 ]] ; then echo "FAILED to download ${ZIPFILE}" ; exit ${STATUS} ; fi

unzip -q ${ZIPFILE}
if [[ ! -e ${PLATFORM}/sync_gateway ]] ; then echo "FAILED to find ${PLATFORM}/sync_gateway" ; exit 127 ; fi
cp         ${PLATFORM}/sync_gateway   ${SYNCGATE_PATH}

popd                 2>&1 > /dev/null

#--------------------------------------------  run tests

cd couchbase-lite-android/CouchbaseLiteProject
echo "********RUNNING: ./build_android_testing.sh ***********"

./build_android_testing.sh 2>&1 | tee ${WORKSPACE}/android_testing_err.log

echo ".......................................creating avd"
echo no | android create avd -n ${EMULATOR} -t ${AND_TARG} --abi armeabi-v7a --force

echo ".......................................stopping emulator"
./stop_android_emulator.sh  || true
echo ".......................................starting emulator"
./start_android_emulator.sh ${EMULATOR} -no-window -verbose -no-audio &
echo ".......................................waiting for emulator"
echo ""
sleep 10
adb wait-for-device
sleep 90
echo "ADB log for build ${BUILD_NUMBER}"  > ${WORKSPACE}/adb.log
adb logcat                               >> ${WORKSPACE}/adb.log &

echo ".......................................starting sync_gateway"
killall sync_gateway || true
pushd  ${SYNCGATE_PATH} 2>&1 > /dev/null

./sync_gateway  ${WORKSPACE}/cblite-tests/config/admin_party.json &
jobs
popd                    2>&1 > /dev/null

#--------------------------------------------  run unit tests

echo "********RUNNING: ./run_android_unit_tests.sh  *************"
./run_android_unit_tests.sh 2>&1 | tee ${WORKSPACE}/android_unit_tests_err.log

#
#                     # generates tap.out result file
#./buildandroid.sh
#cp /tmp/tap.out ${WORKSPACE}/build_cblite_android/tap.log

                     # copy artifacts
#cp ${WORKSPACE}/couchbase-lite-android/CouchbaseLiteProject/CBLite/build/reports/instrumentTests/connected/*.html ${WORKSPACE}/build_cblite_android/


echo "build started: ${BUILD_ID}"        >> ${WORKSPACE}/adb.log

# kill background jobs
jobs
kill %adb                       || true
kill %./start_android_emulator  || true
kill %./sync_gateway            || true
