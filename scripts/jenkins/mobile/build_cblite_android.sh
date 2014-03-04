#!/bin/bash
#          
#          run by jenkins jobs: 'build_cblite_android_master'
#                               'build_cblite_android_stable'
#                               'build_cblite_android'
#          
#          with job paramters used in this script:
#             
#             SYNCGATE_VERSION
#             
#          and with job paramters passed on to downstream jobs:
#             
#             UPLOAD_ARTIFACTS        (boolean)
#             UPLOAD_VERSION_CBLITE
#             UPLOAD_VERSION_CBLITE_EKTORP
#             UPLOAD_VERSION_CBLITE_JAVASCRIPT
#             UPLOAD_MAVEN_REPO_URL
#             UPLOAD_USERNAME
#             UPLOAD_PASSWORD
#          
#          and called with paramters:         branch_name  release_number
#          
#            by build_cblite_android_master:     master         0.0
#            by build_cblite_android_stable:     stable         1.0
#            by build_cblite_android:          ${GITSPEC}       9.8.7
#          
source ~jenkins/.bash_profile
export DISPLAY=:0
set -e

function usage
    {
    echo -e "\nuse:  ${0}   branch_name  release_number\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
VERSION=${2}
REVISION=${VERSION}-${BUILD_NUMBER}

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds
DOCS_ZIP=cblite_android_javadocs_${REVISION}.zip

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

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

cd ${WORKSPACE}
echo ============================================  sync couchbase-lite-android-liteserv
echo ============================================  to ${GITSPEC}

if [[ ! -d couchbase-lite-android-liteserv ]] ; then git clone https://github.com/couchbase/couchbase-lite-android-liteserv.git ; fi
cd couchbase-lite-android-liteserv
git checkout      ${GITSPEC}
git pull  origin  ${GITSPEC}
git submodule init
git submodule update
git show --stat

cd ${WORKSPACE}
echo ============================================  sync cblite-tests
echo ============================================  to master

if [[ ! -d cblite-tests ]] ; then git clone https://github.com/couchbaselabs/cblite-tests.git ; fi
cd cblite-tests
git pull

cd ${WORKSPACE}
echo ============================================  install sync_gateway
rm   -rf ${DOWNLOAD}
mkdir -p ${DOWNLOAD}
pushd    ${DOWNLOAD} 2>&1 > /dev/null

SGW_PKG=couchbase-sync-gateway_0.0-109_amd64.deb

wget --no-verbose ${CBFS_URL}/${SGW_PKG}
STATUS=$?
if [[ ${STATUS} > 0 ]] ; then echo "FAILED to download ${SGW_PKG}" ; exit ${STATUS} ; fi

sudo dpkg --remove   couchbase-sync-gateway || true
sudo dpkg --install  ${SGW_PKG} --recursive ${SYNCGATE_PATH}

# unzip -q ${ZIPFILE}
# if [[ ! -e ${PLATFORM}/sync_gateway ]] ; then echo "FAILED to find ${PLATFORM}/sync_gateway" ; exit 127 ; fi
# cp         ${PLATFORM}/sync_gateway   ${SYNCGATE_PATH}

popd                 2>&1 > /dev/null

echo ============================================  run tests
cd ${WORKSPACE}/couchbase-lite-android-liteserv
cp extra/jenkins_build/* .
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
adb logcat -v time                        >> ${WORKSPACE}/adb.log &

echo ".......................................starting sync_gateway"
killall sync_gateway || true

# pushd  ${SYNCGATE_PATH} 2>&1 > /dev/null
# ./sync_gateway  ${WORKSPACE}/cblite-tests/config/admin_party.json &

sync_gateway  ${WORKSPACE}/cblite-tests/config/admin_party.json &
jobs

# popd                    2>&1 > /dev/null

echo ============================================  run unit tests
echo "********RUNNING: ./run_android_unit_tests.sh  *************"
./run_android_unit_tests.sh 2>&1 | tee ${WORKSPACE}/android_unit_tests_err.log

FAILS=`grep -i FAIL ${WORKSPACE}/android_unit_tests_err.log | wc -l`
if [[ $((FAILS)) > 0 ]]
    then
    echo "---------------------------- ${FAILS} test FAILs -----------------------"
       cat -n ${WORKSPACE}/android_unit_tests_err.log | grep -i FAIL
    echo "------------------------------------------------------------------------"
    exit ${FAILS}
fi

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

echo ============================================  generate javadocs

cd ${WORKSPACE}/couchbase-lite-android-liteserv
./gradlew :libraries:couchbase-lite-java-core:javadoc
cd libraries/couchbase-lite-java-core/build/docs/javadoc

echo ============================================ zip up ${DOCS_ZIP}
zip -r ${WORKSPACE}/${DOCS_ZIP} *

echo ============================================ upload ${CBFS_URL}/${DOCS_ZIP}
curl -XPUT --data-binary @${WORKSPACE}/${DOCS_ZIP} ${CBFS_URL}/${DOCS_ZIP}


echo ============================================ removing couchbase-sync-gateway
sudo dpkg --remove   couchbase-sync-gateway || true
echo ============================================ `date`

