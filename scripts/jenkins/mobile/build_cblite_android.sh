#!/bin/bash
#          
#          run by jenkins jobs: 'build_cblite_android_master'
#                               'build_cblite_android_100'
#          
#          with job paramters used in this script:
#             
#             SYNCGATE_VERSION  ( hard-coded to run on ubuntu-x64 )
#                                 now of the form n.n-mmmm
#             
#          and called with paramters:         branch_name  release_number   edition
#          
#            by build_cblite_android_master:     master         0.0.0      community
#            by build_cblite_android_100:        release/1.0.0  1.0.0      enterprise
#          
#          in an environment with these variables set:
#          
#            MAVEN_UPLOAD_USERNAME
#            MAVEN_UPLOAD_PASSWORD
#          
#          produces these log files, sampled in this script's output:
#            
#            BLD_LOG - 00_android_build.log
#            ADB_LOG - 01_adb.log
#            AUT_LOG - 02_android_unit_test.log
#            UPL_LOG - 03_upload_android_artifacts.log
#            PKG_LOG - 04_android_package.log
#            DOC_LOG - 05_javadocs.log
#            ZIP_LOG - 06_package_javadocs.log
#            
##############
source ~jenkins/.bash_profile
export DISPLAY=:0
set -e

LOG_TAIL=-24
CURL_CMD="curl --fail --retry 10"


function usage
    {
    echo -e "\nuse:  ${0}   branch_name  release_number  edition (community or enterprise)\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

JOB_SUFX=${GITSPEC}
                      vrs_rex='([0-9]{1,})\.([0-9]{1,})\.([0-9]{1,})'
if [[ ${JOB_SUFX} =~ $vrs_rex ]]
    then
    JOB_SUFX=""
    for N in 1 2 3 ; do
        if [[ $N -eq 1 ]] ; then            JOB_SUFX=${BASH_REMATCH[$N]} ; fi
        if [[ $N -eq 2 ]] ; then JOB_SUFX=${JOB_SUFX}${BASH_REMATCH[$N]} ; fi
        if [[ $N -eq 3 ]] ; then JOB_SUFX=${JOB_SUFX}${BASH_REMATCH[$N]} ; fi
    done
fi

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
VERSION=${2}
REVISION=${VERSION}-${BUILD_NUMBER}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
EDITION=${3}

export MAVEN_UPLOAD_VERSION=${REVISION}
export MAVEN_UPLOAD_REPO_URL=http://files.couchbase.com/maven2/

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds
DOCS_ZIP=cblite_android_javadocs_${REVISION}.zip

PLATFORM=linux-amd64

if [[ ${EDITION} =~ 'community' ]]
  then
    SGW_PKG=couchbase-sync-gateway_${SYNCGATE_VERSION}_amd64-${EDITION}.deb
else
    SGW_PKG=couchbase-sync-gateway_${SYNCGATE_VERSION}_amd64.deb
fi

                #  "android-19"
AND_TARG=4
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

export MAVEN_LOCAL_REPO=${ANDR_LITESRV_DIR}/release/m2

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

JAVA_VER_FILE=${ANDR_LITESRV_DIR}/libraries/couchbase-lite-java-core/src/main/java/com/couchbase/lite/support/Version.java
echo ============================================  instantiate tokens in source file
echo ${JAVA_VER_FILE}

sed -i.ORIG  -e 's,\${VERSION_NAME},'${VERSION}','      ${JAVA_VER_FILE}
sed -i       -e 's,\${VERSION_CODE},'${BUILD_NUMBER}',' ${JAVA_VER_FILE}

diff ${JAVA_VER_FILE} ${JAVA_VER_FILE}.ORIG || true


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

if [[ ! -d ${MAVEN_LOCAL_REPO} ]] ; then mkdir -p ${MAVEN_LOCAL_REPO} ; fi

MANIFEST_FILE="${ANDR_LITESRV_DIR}/couchbase-lite-android-liteserv/src/main/AndroidManifest.xml"
echo ======== insert build meta-data ==============
echo ${MANIFEST_FILE}

sed -i.ORIG  -e 's,android:versionCode=".*",android:versionCode="'${BUILD_NUMBER}'",'  ${MANIFEST_FILE}
sed -i       -e 's,android:versionName=".*",android:versionName="'${VERSION}'",'       ${MANIFEST_FILE}

diff ${MANIFEST_FILE} ${MANIFEST_FILE}.ORIG || true

echo ============================================  build android
cd ${ANDR_LITESRV_DIR}
cp extra/jenkins_build/* .

echo "********RUNNING: ./build_android.sh *******************"
( ./build_android.sh   2>&1 )                >> ${WORKSPACE}/00_android_build.log

if  [[ -e ${WORKSPACE}/00_android_build.log ]]
    then
    echo
    echo "===================================== ${WORKSPACE}/00_android_build.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${WORKSPACE}/00_android_build.log
fi
echo ============================================  UNDO instantiate tokens
cp  ${JAVA_VER_FILE}.ORIG ${JAVA_VER_FILE}
cp  ${MANIFEST_FILE}.ORIG ${MANIFEST_FILE}

cd ${ANDR_LITESRV_DIR}
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
echo "ADB log for build ${BUILD_NUMBER}"      > ${WORKSPACE}/01_adb.log
( adb logcat -v time   2>&1 )                >> ${WORKSPACE}/01_adb.log &

if  [[ -e ${WORKSPACE}/01_adb.log ]]
    then
    echo
    echo "===================================== ${WORKSPACE}/01_adb.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${WORKSPACE}/01_adb.log
fi

echo ".......................................starting sync_gateway"
killall sync_gateway || true

${SYNCGATE_PATH} ${ANDR_DIR}/cblite-tests/config/admin_party.json &
jobs

cd ${ANDR_LITESRV_DIR}
echo ============================================  run unit tests
echo "********RUNNING: ./run_android_unit_tests.sh  *************"

( ./run_android_unit_tests.sh  2>&1 )        >> ${WORKSPACE}/02_android_unit_test.log

if  [[ -e ${WORKSPACE}/02_android_unit_test.log ]]
    then
    echo
    echo "===================================== ${WORKSPACE}/02_android_unit_test.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${WORKSPACE}/02_android_unit_test.log
fi
echo "http://factory.hq.couchbase.com:8080/job/build_cblite_android_master/ws/app-under-test/android/couchbase-lite-android-liteserv/libraries/couchbase-lite-android/build/reports/androidTests/connected/index.html"

FAILS=`grep -i FAIL ${WORKSPACE}/02_android_unit_test.log | wc -l`
if [[ $((FAILS)) > 0 ]]
    then
    echo "---------------------------- ${FAILS} test FAILs -----------------------"
       cat -n ${WORKSPACE}/02_android_unit_test.log | grep -i FAIL
    echo "------------------------------------------------------------------------"
    exit ${FAILS}
fi

#
#                     # generates tap.out result file
#./buildandroid.sh
#cp /tmp/tap.out ${WORKSPACE}/build_cblite_android/tap.log

                     # copy artifacts
#cp ${WORKSPACE}/couchbase-lite-android/CouchbaseLiteProject/CBLite/build/reports/instrumentTests/connected/*.html ${WORKSPACE}/build_cblite_android/


echo "build started: ${BUILD_ID}"        >> ${WORKSPACE}/01_adb.log

# kill background jobs
jobs
kill %adb                       || true
kill %./start_android_emulator  || true
kill %./sync_gateway            || true

echo "********RUNNING: ./upload_android_artifacts.sh *******************"
( ./upload_android_artifacts.sh 2>&1 )       >> ${WORKSPACE}/03_upload_android_artifacts.log

if  [[ -e ${WORKSPACE}/03_upload_android_artifacts.log ]]
    then
    echo
    echo "===================================== ${WORKSPACE}/03_upload_android_artifacts.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${WORKSPACE}/03_upload_android_artifacts.log
fi

echo ============================================  build android zipfile

if [[ ! -d ${MAVEN_LOCAL_REPO} ]] ; then mkdir -p ${MAVEN_LOCAL_REPO} ; fi

cd ${ANDR_LITESRV_DIR}/release
cp ${WORKSPACE}/build/license/couchbase-lite/LICENSE_${EDITION}.txt  LICENSE.txt

MVN_ZIP=couchbase-lite-${REVISION}-android.zip
AND_ZIP=${MVN_ZIP}

if [[ ${EDITION} =~ 'community' ]]
    then
    AND_ZIP=couchbase-lite-${REVISION}-android-${EDITION}.zip
fi
rm -f                                           ${WORKSPACE}/04_android_package.log
                      ./zip_jars.sh ${REVISION} ${WORKSPACE}/04_android_package.log

if  [[ -e ${WORKSPACE}/04_android_package.log ]]
    then
    echo "===================================== ${WORKSPACE}/04_android_package.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${WORKSPACE}/04_android_package.log
fi

echo ============================================ upload ${CBFS_URL}/${AND_ZIP}
echo  ${ANDR_LITESRV_DIR}/release/target/${MVN_ZIP}
file  ${ANDR_LITESRV_DIR}/release/target/${MVN_ZIP} || exit 99
cp    ${ANDR_LITESRV_DIR}/release/target/${MVN_ZIP} ${WORKSPACE}/${AND_ZIP}
echo  ${WORKSPACE}/${AND_ZIP}

${CURL_CMD} -XPUT --data-binary @${WORKSPACE}/${AND_ZIP} ${CBFS_URL}/${AND_ZIP}


cd ${ANDR_LITESRV_DIR}
echo ============================================  generate javadocs
JAVADOC_CMD='./gradlew :libraries:couchbase-lite-java-core:javadoc'

( ${JAVADOC_CMD}  2>&1 )                     >> ${WORKSPACE}/05_javadocs.log

if  [[ -e ${WORKSPACE}/05_javadocs.log ]]
    then
    echo
    echo "===================================== ${WORKSPACE}/05_javadocs.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${WORKSPACE}/05_javadocs.log
fi
cd libraries/couchbase-lite-java-core/build/docs/javadoc
echo ============================================ zip up ${DOCS_ZIP}
( zip -r ${WORKSPACE}/${DOCS_ZIP} * 2>&1 )  >> ${WORKSPACE}/06_package_javadocs.log

if  [[ -e ${WORKSPACE}/06_package_javadocs.log ]]
    then
    echo
    echo "===================================== ${WORKSPACE}/06_package_javadocs.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${WORKSPACE}/06_package_javadocs.log
fi

echo ============================================ upload  ${CBFS_URL}/${DOCS_ZIP}
${CURL_CMD} -XPUT --data-binary @${WORKSPACE}/${DOCS_ZIP} ${CBFS_URL}/${DOCS_ZIP}


echo ============================================ removing couchbase-sync-gateway
sudo dpkg --remove   couchbase-sync-gateway     || true

echo ============================================ set default value of BLD_TO_RELEASE
echo ============================================ in upload_cblite_android_artifacts_${GITSPEC}
echo ============================================ to ${REVISION}

${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl -j release_android_artifacts_${JOB_SUFX}       -p BLD_TO_RELEASE   -v ${REVISION}

${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl -j mobile_functional_tests_ios_${JOB_SUFX}     -p LITESERV_VERSION -v ${REVISION}
${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl -j mobile_functional_tests_android_${JOB_SUFX} -p LITESERV_VERSION -v ${REVISION}

echo ============================================ `date`

