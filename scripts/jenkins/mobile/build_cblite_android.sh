#!/bin/bash
#          
#          run by jenkins jobs: 'build_cblite_android_master-community', 'build_cblite_android_master-enterprise'
#                               'build_cblite_android_100-community',    'build_cblite_android_100-enterprise'
#                               'build_cblite_android_101-community',    'build_cblite_android_101-enterprise'
#                               'build_cblite_android_102-community',    'build_cblite_android_102-enterprise'
#                               'build_cblite_android_dev-branch'
#          
#          with job paramters used in this script:
#             
#             SYNCGATE_VERSION  ( hard-coded to run on ubuntu-x64 )
#                                 now of the form n.n-mmmm
#             
#          and called with paramters:         branch_name  release_number  build_number  edition              [ NO_PKG ]
#          
#            by build_cblite_android_master-*     master           0.0.0       1234      community/enterprise
#            by build_cblite_android_100-*        release/1.0.0    1.0.0       1234      community/enterprise
#            by build_cblite_android_101-*        release/1.0.1    1.0.1       1234      community/enterprise
#            by build_cblite_android_102-*        release/1.0.2    1.0.2       1234      community/enterprise
#            by build_cblite_android_dev-branch   <dev_branch>     0.0.0       1234      community              True
#            
#          in an environment with these variables set:
#          
#            MAVEN_UPLOAD_USERNAME
#            MAVEN_UPLOAD_PASSWORD
#          
#                    'build_number' is the jenkins build number of the parent job.  For example,
#              
#            build_cblite_android_master calls: build_cblite_android_master-community
#                                               build_cblite_android_master-enterprise
#               . . .
#            build_cblite_android_102    calls: build_cblite_android_102-community
#                                               build_cblite_android_102-enterprise
#              
#          
#          Produces these log files, sampled in this script's output:
#            
#            SRC_LOG - 00_android_src_jarfile.log
#            BLD_LOG - 01_android_build.log
#            ADB_LOG - 02_adb.log
#            AUT_LOG - 03_android_unit_test.log
#            UPL_LOG - 04_upload_android_artifacts.log
#            DOC_LOG - 05_javadocs.log
#            ZIP_LOG - 06_package_javadocs.log
#            PKG_LOG - 07_android_package.log
#        
#        
#    NOTE:  If any value is supplied for the optional 5th param ( NO_PKG ), then the downstream tasks,
#           such as building javadocs, uploading a zip file, and setting default values for downstream
#           jenkins jobs, are all skipped.
#            
##############
#            
#   see:     http://redsymbol.net/articles/bash-exit-traps/
#
function kill_child_processes
    {
    echo ============================================ killing child processes
    jobs -l | awk '{print "kill    "$2" || true"}' | bash
    echo ============================================ try again after 15 sec.
    sleep  15
  # for I in {a..o} ; do echo -n '=' ; sleep 1 ; done ; echo
    jobs -l | awk '{print "kill -9 "$2" || true"}' | bash
    }
function finish
    {
    EXIT_STATUS=$?
    if [[ ${EXIT_STATUS} > 0 ]]
        then
        echo ============================================
        echo ============  SIGNAL CAUGHT:  ${EXIT_STATUS}
        echo ============================================
    fi
    kill_child_processes
    echo ============================================ make file handles closed
  # for I in {a..o} ; do echo -n '=' ; sleep 1 ; done ; echo
    sleep 15
    echo ============================================  `date`
    exit ${EXIT_STATUS}
    }
trap finish EXIT
##############

source ~jenkins/.bash_profile
export DISPLAY=:0
set -e

LOG_TAIL=-24


function usage
    {
    echo -e "\nuse:  ${0}   branch_name  release_number  build_number  edition (community or enterprise)  [ no-package ]\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

JOB_SUFX=${GITSPEC}
                      vrs_rex='([0-9]{1,})\.([0-9]{1,})\.([0-9]{1,})(\.([0-9]{1,}))?'
if [[ ${JOB_SUFX} =~ $vrs_rex ]]
    then
    JOB_SUFX=""
    for N in 1 2 3 5; do
        if [[ $N -eq 1 ]] ; then            JOB_SUFX=${BASH_REMATCH[$N]} ; fi
        if [[ $N -eq 2 ]] ; then JOB_SUFX=${JOB_SUFX}${BASH_REMATCH[$N]} ; fi
        if [[ $N -eq 3 ]] ; then JOB_SUFX=${JOB_SUFX}${BASH_REMATCH[$N]} ; fi
        if [[ $N -eq 5 ]] ; then JOB_SUFX=${JOB_SUFX}${BASH_REMATCH[$N]} ; fi
    done
fi

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
VERSION=${2}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
BLD_NUM=${3}
REVISION=${VERSION}-${BLD_NUM}

if [[ ! ${4} ]] ; then usage ; exit 66 ; fi
EDITION=${4}
EDN_PRFX=`echo ${EDITION} | tr '[a-z]' '[A-Z]'`

if [[   ${5} ]] ; then NO_PKG=${5} ; NO_DOWNSTREAM=skip_it ; fi

LOG_DIR_NAME=${EDITION}_logs
LOG_DIR=${WORKSPACE}/${LOG_DIR_NAME}
if [[ -e ${LOG_DIR} ]] ; then rm -rf ${LOG_DIR} ; fi
mkdir -p ${LOG_DIR}

#  sometimes android source is branched before sync_gateway, so until the sync_gateway builds can
#  set the SYNCGATE_VERSION we may have to use an old one
sgw_rex='^([0-9]{1,}\.[0-9]{1,}\.[0-9]{1,}(\.[0-9]{1,})?)'
SGW_VER=${VERSION}
if [[ ${SYNCGATE_VERSION} =~ $sgw_rex ]] ; then SGW_VER=${BASH_REMATCH[1]} ; fi

PKG_SRCD=s3://packages.couchbase.com/builds/mobile/sync_gateway/${SGW_VER}/${SYNCGATE_VERSION}
PKGSTORE=s3://packages.couchbase.com/builds/mobile/android/${VERSION}/${REVISION}
PUT_CMD="s3cmd put -P"
GET_CMD="s3cmd get"

export MAVEN_UPLOAD_VERSION=${REVISION}
export MAVEN_UPLOAD_REPO_URL=http://files.couchbase.com/maven2/

SRC_JAR=couchbase-lite-android-source_${REVISION}.jar
DOCS_JAR=couchbase-lite-android-javadocs-${EDITION}_${REVISION}.jar

PLATFORM=linux-amd64
SGW_PKG=couchbase-sync-gateway-${EDITION}_${SYNCGATE_VERSION}_x86_64.deb

                #  "android-19"
AND_TARG=3
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

( jar cvf ${WORKSPACE}/${SRC_JAR} * 2>&1 )   >> ${LOG_DIR}/00_android_src_jarfile.log
if  [[ -e ${LOG_DIR}/00_android_src_jarfile.log ]]
    then
    echo
    echo "================================================ 00_android_src_jarfile.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/00_android_src_jarfile.log
fi

JAVA_VER_FILE=${ANDR_LITESRV_DIR}/libraries/couchbase-lite-java-core/src/main/java/com/couchbase/lite/support/Version.java
echo ============================================  instantiate tokens in source file
echo ${JAVA_VER_FILE}

cp ${JAVA_VER_FILE} ${JAVA_VER_FILE}.ORIG

sed -i  -e 's,\${VERSION_NAME},'${VERSION}','  ${JAVA_VER_FILE}
sed -i       -e 's,\${VERSION_CODE},'${BLD_NUM}','  ${JAVA_VER_FILE}

diff ${JAVA_VER_FILE} ${JAVA_VER_FILE}.ORIG || true
rm -rf ${JAVA_VER_FILE}.ORIG


cd ${ANDR_DIR}
echo ============================================  sync cblite-tests
echo ============================================  to master

if [[ ! -d cblite-tests ]] ; then git clone https://github.com/couchbaselabs/cblite-tests.git ; fi
cd cblite-tests
git pull

cd ${WORKSPACE}
echo ============================================  install sync_gateway
echo     ${PKG_SRCD}/${SGW_PKG}
rm   -rf ${DOWNLOAD}
mkdir -p ${DOWNLOAD}
pushd    ${DOWNLOAD} 2>&1 > /dev/null

${GET_CMD}  ${PKG_SRCD}/${SGW_PKG}
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

sed -i.ORIG  -e 's,android:versionCode=".*",android:versionCode="'${BLD_NUM}'",'  ${MANIFEST_FILE}
sed -i       -e 's,android:versionName=".*",android:versionName="'${VERSION}'",'  ${MANIFEST_FILE}

diff ${MANIFEST_FILE} ${MANIFEST_FILE}.ORIG || true

echo ============================================  build android
cd ${ANDR_LITESRV_DIR}
cp release/*.*  .

echo "********RUNNING: ./build_android.sh *******************"
( ./build_android.sh   2>&1 )                >> ${LOG_DIR}/01_android_build.log

if  [[ -e ${LOG_DIR}/01_android_build.log ]]
    then
    echo
    echo "================================================ 01_android_build.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/01_android_build.log
fi
echo ============================================  UNDO instantiate tokens
cd  ${ANDR_LITESRV_DIR}
cp  ${JAVA_VER_FILE}.ORIG ${JAVA_VER_FILE}
rm  ${JAVA_VER_FILE}.ORIG
cp  ${MANIFEST_FILE}.ORIG ${MANIFEST_FILE}
rm  ${MANIFEST_FILE}.ORIG

cd  ${ANDR_LITESRV_DIR}
echo ============================================  run tests
echo ".......................................creating avd"
echo no | android create avd -n ${EMULATOR} -t ${AND_TARG} --abi armeabi-v7a --force

echo ".......................................stopping emulator"
./stop_android_emulator.sh  || true
echo ".......................................starting emulator"
# remove Android emulator temporary directory
rm -rf /tmp/android-${USER}
./start_android_emulator.sh ${EMULATOR} -no-window -verbose -no-audio -no-skin &
echo ".......................................waiting for emulator"
echo ""
sleep 10
adb wait-for-device
sleep 30

OUT=`adb shell getprop init.svc.bootanim`
while [[ ${OUT:0:7}  != 'stopped' ]]
  do
    OUT=`adb shell getprop init.svc.bootanim`
    echo 'Waiting for emulator to fully boot...'
    sleep 10
done
sleep 30


echo "ADB log for build ${BLD_NUM}"           > ${LOG_DIR}/02_adb.log
( adb logcat -v time   2>&1 )                >> ${LOG_DIR}/02_adb.log &

if  [[ -e ${LOG_DIR}/02_adb.log ]]
    then
    echo
    echo "================================================ 02_adb.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/02_adb.log
fi

echo ".......................................starting sync_gateway"
killall sync_gateway || true
sleep 30

${SYNCGATE_PATH} ${ANDR_DIR}/cblite-tests/config/admin_party.json &
jobs

cd ${ANDR_LITESRV_DIR}
echo ============================================  run unit tests
echo "********RUNNING: ./run_android_unit_tests.sh  *************"

( ./run_android_unit_tests.sh  2>&1 )        >> ${LOG_DIR}/03_android_unit_test.log

if  [[ -e ${LOG_DIR}/03_android_unit_test.log ]]
    then
    echo
    echo "================================================ 03_android_unit_test.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/03_android_unit_test.log
fi
echo "http://factory.hq.couchbase.com:8080/job/build_cblite_android_master/ws/app-under-test/android/couchbase-lite-android-liteserv/libraries/couchbase-lite-android/build/reports/androidTests/connected/index.html"

FAILS=`grep -i FAIL ${LOG_DIR}/03_android_unit_test.log | wc -l`
if [[ $((FAILS)) > 0 ]]
    then
    echo "---------------------------- ${FAILS} test FAILs -----------------------"
       cat -n ${LOG_DIR}/03_android_unit_test.log | grep -i FAIL
    echo "------------------------------------------------------------------------"
    exit ${FAILS}
fi
if [[ ${NO_PKG} ]] ; then exit ${FAILS} ; fi

#
#                     # generates tap.out result file
#./buildandroid.sh
#cp /tmp/tap.out ${WORKSPACE}/build_cblite_android/tap.log

                     # copy artifacts
#cp ${WORKSPACE}/couchbase-lite-android/CouchbaseLiteProject/CBLite/build/reports/instrumentTests/connected/*.html ${WORKSPACE}/build_cblite_android/


echo "build started: ${BUILD_ID}"            >> ${LOG_DIR}/02_adb.log

kill_child_processes

echo "********RUNNING: ./upload_android_artifacts.sh *******************"
( ./upload_android_artifacts.sh 2>&1 )       >> ${LOG_DIR}/04_upload_android_artifacts.log

if  [[ -e ${LOG_DIR}/04_upload_android_artifacts.log ]]
    then
    echo
    echo "================================================ 04_upload_android_artifacts.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/04_upload_android_artifacts.log
fi

cd ${ANDR_LITESRV_DIR}
echo ============================================  generate javadocs
JAVADOC_CMD='./gradlew :libraries:couchbase-lite-java-core:generateJavadocs'

( ${JAVADOC_CMD}  2>&1 )                     >> ${LOG_DIR}/05_javadocs.log

if  [[ -e ${LOG_DIR}/05_javadocs.log ]]
    then
    echo
    echo "================================================ 05_javadocs.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/05_javadocs.log
fi
cd libraries/couchbase-lite-java-core/build/docs/javadoc
echo ============================================ jar up ${DOCS_JAR}
( jar cvf ${WORKSPACE}/${DOCS_JAR} * 2>&1 )  >> ${LOG_DIR}/06_package_javadocs.log

if  [[ -e ${LOG_DIR}/06_package_javadocs.log ]]
    then
    echo
    echo "================================================ 06_package_javadocs.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/06_package_javadocs.log
fi

echo ============================================ upload  ${PKGSTORE}/${DOCS_JAR}
${PUT_CMD}  ${WORKSPACE}/${DOCS_JAR}                      ${PKGSTORE}/${DOCS_JAR}

echo ============================================  build android zipfile

if [[ ! -d ${MAVEN_LOCAL_REPO} ]] ; then mkdir -p ${MAVEN_LOCAL_REPO} ; fi

cd ${ANDR_LITESRV_DIR}/release
cp ${WORKSPACE}/build/license/couchbase-lite/LICENSE_${EDITION}.txt  LICENSE.txt

MVN_ZIP=couchbase-lite-${REVISION}-android.zip
AND_ZIP=couchbase-lite-android-${EDITION}_${REVISION}.zip

rm -f                                           ${LOG_DIR}/07_android_package.log
                      ./zip_jars.sh ${REVISION} ${LOG_DIR}/07_android_package.log

if  [[ -e ${LOG_DIR}/07_android_package.log ]]
    then
    echo "================================================ 07_android_package.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/07_android_package.log
fi

echo ============================================ create ${WORKSPACE}/${AND_ZIP}
echo  ${ANDR_LITESRV_DIR}/release/target/${MVN_ZIP}
file  ${ANDR_LITESRV_DIR}/release/target/${MVN_ZIP}  || exit 99
cp    ${ANDR_LITESRV_DIR}/release/target/${MVN_ZIP}      ${WORKSPACE}/${AND_ZIP}

echo "=====================================" >> ${LOG_DIR}/07_android_package.log
( zip -g ${WORKSPACE}/${AND_ZIP} \
                    LICENSE.txt     2>&1 )   >> ${LOG_DIR}/07_android_package.log
echo "=====================================" >> ${LOG_DIR}/07_android_package.log
cd ${WORKSPACE}
( zip -g ${AND_ZIP} ${DOCS_JAR}  \
                    ${SRC_JAR}      2>&1 )   >> ${LOG_DIR}/07_android_package.log
echo "=====================================" >> ${LOG_DIR}/07_android_package.log
( unzip -l  ${WORKSPACE}/${AND_ZIP} 2>&1 )   >> ${LOG_DIR}/07_android_package.log

if  [[ -e ${LOG_DIR}/07_android_package.log ]]
    then
    echo "================================================ 07_android_package.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/07_android_package.log
fi

if [[ ${NO_DOWNSTREAM} ]] ; then exit ${FAILS} ; fi
echo ============================================ upload ${PKGSTORE}/${AND_ZIP}
echo        ${WORKSPACE}/${AND_ZIP}
${PUT_CMD}  ${WORKSPACE}/${AND_ZIP}                      ${PKGSTORE}/${AND_ZIP}


echo ============================================ upload logs ${PKGSTORE}/${LOG_DIR_NAME}
${PUT_CMD}  ${LOG_DIR}/*.log                                  ${PKGSTORE}/${LOG_DIR_NAME}/

echo ============================================ removing couchbase-sync-gateway
sudo dpkg --remove   couchbase-sync-gateway     || true

echo  ============================================== update default value of release jobs
#${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl -j mobile_functional_tests_android_${JOB_SUFX}  -p ${EDN_PRFX}_ANDROID_VERSION -v ${REVISION}
${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl -j prepare_release_android_${JOB_SUFX}          -p ${EDN_PRFX}_BLD_TO_RELEASE  -v ${REVISION}


############## EXIT function finish
