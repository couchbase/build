#!/bin/bash
#          
#          run by jenkins job 'build_phonegap_plugin'
#          
#          with job paramters:  
#                   
#                   IOS_BLDNUM    -- get IOS_BLDNUM artifacts
#                   
#                   ANDROID_REL   -- get ANDROID_REL artifacts
#          
#          and cmdline args:  branch_name  release number
#          
#                   e.g.:     master         0.0
#                   e.g.:     stable         1.0
#          
#          
source ~jenkins/.bash_profile
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

env | grep -iv password | grep -iv passwd | sort -u
echo =========================================================

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds
ANRL_URL=http://packages.couchbase.com/releases/couchbase-lite/android/${ANDROID_REL}
TDSO_JAR=s3://packages.couchbase.com/releases/couchbase-lite/android/external/${VERSION}/td_collator_so.jar


BUILD_DIR=${WORKSPACE}/build
PHONE_DIR=${WORKSPACE}/couchbase-lite-phonegap-plugin-builder
DOWN_IDIR=${WORKSPACE}/download/ios
DOWN_ADIR=${WORKSPACE}/download/android
STAGE_DIR=${WORKSPACE}/staging
IOS_DIR=${STAGE_DIR}/lib/ios
AND_DIR=${STAGE_DIR}/lib/android

cd ${WORKSPACE}
echo ======== download ios ===================================

if [[ -e ${DOWN_IDIR} ]] ; then rm -rf ${DOWN_IDIR} ; fi
mkdir -p ${DOWN_IDIR}
pushd    ${DOWN_IDIR}    2>&1 >/dev/null

IOS_PKG=cblite_ios_${IOS_BLDNUM}.zip
wget --no-verbose ${CBFS_URL}/${IOS_PKG}
STATUS=$?
if [[ ${STATUS} > 0 ]] ; then echo "FAILED to download ${IOS_PKG}" ; exit ${STATUS} ; fi

unzip -q ${IOS_PKG}

if [[ -e ${STAGE_DIR} ]] ; then rm -rf ${STAGE_DIR} ; fi
mkdir -p ${IOS_DIR}
cp -r ${DOWN_IDIR}/CouchbaseLite.framework             ${IOS_DIR}
cp -r ${DOWN_IDIR}/CouchbaseLiteListener.framework     ${IOS_DIR}
#cp -r ${DOWN_IDIR}/JavaScriptCore.framework            ${IOS_DIR}
cp -r ${DOWN_IDIR}/Extras/CBLRegisterJSViewCompiler.h  ${IOS_DIR}
cp -r ${DOWN_IDIR}/Extras/libCBLJSViewCompiler.a       ${IOS_DIR}
popd                     2>&1 >/dev/null

cd ${WORKSPACE}
echo ======== download android ===============================

if [[ -e ${DOWN_ADIR} ]] ; then rm -rf ${DOWN_ADIR} ; fi
mkdir -p ${DOWN_ADIR}
pushd    ${DOWN_ADIR}    2>&1 >/dev/null

AND_PKG=couchbase-lite-community-android_${ANDROID_REL}.zip
wget --no-verbose ${ANRL_URL}/${AND_PKG}
STATUS=$?
if [[ ${STATUS} > 0 ]] ; then echo "FAILED to download ${AND_PKG}" ; exit ${STATUS} ; fi

echo ======== expand android =================================
unzip -q ${AND_PKG}
mkdir -p ${AND_DIR}
cp -r ${DOWN_ADIR}/CBLite-1.0.0-beta.jar               ${AND_DIR}
cp -r ${DOWN_ADIR}/CBLiteJavascript-1.0.0-beta.jar     ${AND_DIR}
cp -r ${DOWN_ADIR}/CBLiteListener-1.0.0-beta.jar       ${AND_DIR}
cp -r ${DOWN_ADIR}/commons-io-2.0.1.jar                ${AND_DIR}
cp -r ${DOWN_ADIR}/jackson-core-asl-1.9.2.jar          ${AND_DIR}
cp -r ${DOWN_ADIR}/jackson-mapper-asl-1.9.2.jar        ${AND_DIR}
cp -r ${DOWN_ADIR}/rhino-1.7R3.jar                     ${AND_DIR}
cp -r ${DOWN_ADIR}/servlet-api-2.4.jar                 ${AND_DIR}
cp -r ${DOWN_ADIR}/td_collator_so.jar                  ${AND_DIR}
cp -r ${DOWN_ADIR}/webserver.jar                       ${AND_DIR}
#cd ${AND_DIR}
#echo now is `pwd`
#s3cmd get ${TDSO_JAR}
popd                     2>&1 >/dev/null

echo ======== sync couchbase-lite-phonegap-plugin-builder ====

if [[ ! -d couchbase-lite-phonegap-plugin-builder ]] ; then git clone https://github.com/couchbaselabs/couchbase-lite-phonegap-plugin-builder.git ; fi
cd         couchbase-lite-phonegap-plugin-builder
git pull  origin  ${GITSPEC}
git submodule init
git submodule update
git show --stat

cd ${PHONE_DIR}
echo ======== build ==========================================
cp -r src  ${STAGE_DIR}/src
cp -r www  ${STAGE_DIR}/www

#/usr/local/bin/node prepare_plugin.js

echo ======== test ===========================================


pushd  ${STAGE_DIR}      2>&1 >/dev/null
echo ======== package ========================================
ZIP_FILE=Couchbase-Lite-PhoneGap-Plugin_${REVISION}.zip
zip -r ${ZIP_FILE} *

echo  ======= upload =========================================
echo ................... uploading to ${CBFS_URL}/${ZIP_FILE}
curl -XPUT --data-binary @${ZIP_FILE} ${CBFS_URL}/${ZIP_FILE}

popd                     2>&1 >/dev/null
