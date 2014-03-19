#!/bin/bash
#          
#          run by jenkins jobs: 'build_cblite_android_master'
#                               'build_cblite_android_stable'
#          
#          with job paramters used in this script:
#             
#             SYNCGATE_VERSION  ( hard-coded to run on ubuntu-x64 )
#                                 now of the form n.n-mmmm
#             
#          and called with paramters:         branch_name  release_number
#          
#            by build_cblite_android_master:     master         0.0.0
#            by build_cblite_android_stable:     stable         1.0.0
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
AND_VRSN=${VERSION}.${BUILD_NUMBER}

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds
DOCS_ZIP=cblite_android_javadocs_${REVISION}.zip

PLATFORM=linux-amd64
SGW_PKG=couchbase-sync-gateway_${SYNCGATE_VERSION}_amd64.deb

AND_TARG=24
                #  "android-17"
AND_TARG=1
EMULATOR=cblite

AUT_DIR=${WORKSPACE}/app-under-test
if [[ -e ${AUT_DIR}  ]] ; then rm -rf ${AUT_DIR}  ; fi

DOWNLOAD=${AUT_DIR}/download
SYNC_DIR=${AUT_DIR}/sync_gateway

ANDR_DIR=${AUT_DIR}/android
if [[ -e ${ANDR_DIR} ]] ; then rm -rf ${ANDR_DIR} ; fi
mkdir -p ${ANDR_DIR}

ANDR_LITESRV_DIR=${ANDR_DIR}/couchbase-lite-android-liteserv
ANDR_LITESTS_DIR=${ANDR_DIR}/cblite-tests


echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

cd ${ANDR_DIR}
echo ============================================  sync couchbase-lite-android-liteserv
echo ============================================  to ${GITSPEC}

if [[ ! -d couchbase-lite-android-liteserv ]] ; then git clone https://github.com/couchbase/couchbase-lite-android-liteserv.git ; fi
cd         couchbase-lite-android-liteserv
git checkout      ${GITSPEC}
git pull  origin  ${GITSPEC}
git submodule init
git submodule update
git show --stat

cd ${ANDR_DIR}
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

wget --no-verbose ${CBFS_URL}/${SGW_PKG}
STATUS=$?
if [[ ${STATUS} > 0 ]] ; then echo "FAILED to download ${SGW_PKG}" ; exit ${STATUS} ; fi

# rm   -rf ${SYNC_DIR}
# mkdir -p ${SYNC_DIR}

export SYNCGATE_PATH=/opt/couchbase-sync-gateway/bin/sync_gateway
sudo dpkg --remove   couchbase-sync-gateway || true
sudo dpkg --install  ${SGW_PKG}


popd                 2>&1 > /dev/null

echo ============================================  build android
cd ${ANDR_LITESRV_DIR}
cp extra/jenkins_build/* .

echo "********RUNNING: ./build_android.sh *******************"
./build_android.sh         2>&1 | tee           ${WORKSPACE}/android_build.log
echo "=====================================" >> ${WORKSPACE}/android_build.log

echo ============================================  build android zipfile

MVN_ZIP=com.couchbase.cblite-${VERSION}-android.zip
AND_ZIP=cblite_android_${AND_VRSN}.zip

cd    ${ANDR_LITESRV_DIR}/release                   && ./zip_jars.sh  ${AND_VRSN}
file  ${ANDR_LITESRV_DIR}/release/target/${MVN_ZIP} || exit 99
cp    ${ANDR_LITESRV_DIR}/release/target/${MVN_ZIP} ${WORKSPACE}/${AND_ZIP}

echo ============================================  run tests
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
echo "ADB log for build ${BUILD_NUMBER}"   > ${WORKSPACE}/adb.log
adb logcat -v time                        >> ${WORKSPACE}/adb.log &

echo ".......................................starting sync_gateway"
killall sync_gateway || true

${SYNCGATE_PATH} ${ANDR_DIR}/cblite-tests/config/admin_party.json &
jobs


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

echo ============================================ upload ${CBFS_URL}/${AND_ZIP}
curl -XPUT --data-binary @${WORKSPACE}/${AND_ZIP} ${CBFS_URL}/${AND_ZIP}

echo ============================================  generate javadocs

cd ${ANDR_DIR}/couchbase-lite-android-liteserv
./gradlew :libraries:couchbase-lite-java-core:javadoc
cd libraries/couchbase-lite-java-core/build/docs/javadoc

echo ============================================ zip up ${DOCS_ZIP}
zip -r ${WORKSPACE}/${DOCS_ZIP} *

echo ============================================ upload ${CBFS_URL}/${DOCS_ZIP}
curl -XPUT --data-binary @${WORKSPACE}/${DOCS_ZIP} ${CBFS_URL}/${DOCS_ZIP}


echo ============================================ removing couchbase-sync-gateway
sudo dpkg --remove   couchbase-sync-gateway     || true

echo ============================================ setting default value of BLD_TO_RELEASE in upload_cblite_android_artifacts_${GITSPEC}

${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl -j upload_cblite_android_artifacts_${GITSPEC} -p BLD_TO_RELEASE -v ${REVISION}

echo ============================================ `date`

