#!/bin/bash
#          
#          run by jenkins job 'package_phonegap_plugin'
#          
#          with job paramters:  
#                   
#                   IOS_URL    -- URL for zip file of iOS artifacts
#                              -- example:
# http://factory.couchbase.com/view/build/view/mobile_dev/view/ios/job/build_cblite_ios_100/56/artifact/couchbase-lite-ios/cblite_ios_1.0.0-56.zip
#
#                   ANDROID_URL   -- URL for zip file of Android artifacts
#                                 -- examples:
# http://packages.couchbase.com/releases/couchbase-lite/android/couchbase-lite-community-android_1.0-23.zip
# http://cbfs-ext.hq.couchbase.com/builds/couchbase-lite-0.0.0-262-android-community.zip
#
#                   GITSPEC       -- revision to sync: couchbase-lite-phonegap-plugin-builder
#          
#                   VERSION       -- base of plugin build number (e.g., 1.0)
#          
#          
source ~jenkins/.bash_profile
set -e

CURL_CMD="curl --fail --retry 10"


if [[ ! ${GITSPEC} ]] ; then GITSPEC=master ; fi
if [[ ! ${VERSION} ]] ; then VERSION=1.0    ; fi

REVISION=${VERSION}-${BUILD_NUMBER}

env | grep -iv password | grep -iv passwd | sort -u
echo ========================================================= `date`

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds
TDSO_JAR=http://cl.ly/Pr1r/td_collator_so.jar


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

wget --no-verbose -O ios_build.zip ${IOS_URL}
STATUS=$?
if [[ ${STATUS} > 0 ]] ; then echo "FAILED to download ${IOS_URL}" ; exit ${STATUS} ; fi

unzip -q ios_build.zip

if [[ -e ${STAGE_DIR} ]] ; then rm -rf ${STAGE_DIR} ; fi
mkdir -p ${IOS_DIR}
cp -r ${DOWN_IDIR}/CouchbaseLite.framework                               ${IOS_DIR}
mv    ${IOS_DIR}/CouchbaseLite.framework/CouchbaseLite                 ${IOS_DIR}/CouchbaseLite.framework/CouchbaseLite.a
cp -r ${DOWN_IDIR}/CouchbaseLiteListener.framework                       ${IOS_DIR}
mv    ${IOS_DIR}/CouchbaseLiteListener.framework/CouchbaseLiteListener ${IOS_DIR}/CouchbaseLiteListener.framework/CouchbaseLiteListener.a
cp -r ${DOWN_IDIR}/JavaScriptCore.framework                              ${IOS_DIR}
mv    ${IOS_DIR}/JavaScriptCore.framework/JavaScriptCore               ${IOS_DIR}/JavaScriptCore.framework/JavaScriptCore.a
cp -r ${DOWN_IDIR}/Extras/CBLRegisterJSViewCompiler.h                    ${IOS_DIR}
cp -r ${DOWN_IDIR}/Extras/libCBLJSViewCompiler.a                         ${IOS_DIR}
popd                     2>&1 >/dev/null

cd ${WORKSPACE}
echo ======== download android ===============================

if [[ -e ${DOWN_ADIR} ]] ; then rm -rf ${DOWN_ADIR} ; fi
mkdir -p ${DOWN_ADIR}
pushd    ${DOWN_ADIR}    2>&1 >/dev/null

wget --no-verbose -O android_jars.zip ${ANDROID_URL}
STATUS=$?
if [[ ${STATUS} > 0 ]] ; then echo "FAILED to download ${ANDROID_URL}" ; exit ${STATUS} ; fi

echo ======== expand android =================================
unzip -q android_jars.zip
mkdir -p ${AND_DIR}

# copy all jar files into the target directory
cp ${DOWN_ADIR}/**/*.jar ${AND_DIR}

popd                     2>&1 >/dev/null

echo ======== sync couchbase-lite-phonegap-plugin-builder ====

if [[ ! -d couchbase-lite-phonegap-plugin-builder ]] ; then git clone https://github.com/couchbaselabs/couchbase-lite-phonegap-plugin-builder.git ; fi
cd         couchbase-lite-phonegap-plugin-builder
git checkout      ${GITSPEC}
git pull  origin  ${GITSPEC}
git submodule init
git submodule update
git show --stat

cd ${PHONE_DIR}
echo ======== build ==========================================
cp -r src  ${STAGE_DIR}/src
cp -r www  ${STAGE_DIR}/www

/usr/local/bin/node  prepare_plugin.js  ${STAGE_DIR}

echo ======== test ===========================================


pushd  ${STAGE_DIR}      2>&1 >/dev/null
echo ======== package ========================================
ZIP_FILE=Couchbase-Lite-PhoneGap-Plugin_${REVISION}.zip
zip -r ${ZIP_FILE} *

echo  ======= upload =========================================
echo                                         ${CBFS_URL}/${ZIP_FILE}
${CURL_CMD} -XPUT --data-binary @${ZIP_FILE} ${CBFS_URL}/${ZIP_FILE}

popd                     2>&1 >/dev/null
