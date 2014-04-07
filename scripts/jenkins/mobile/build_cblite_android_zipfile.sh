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
#            by build_cblite_android_100:        release/1.0.0  1.0.0
#          
#          in an environment with these variables set:
#          
#            MAVEN_UPLOAD_USERNAME
#            MAVEN_UPLOAD_PASSWORD
#          
#          produces these log files, sampled in this script's output:
#            
#            PKG_LOG - android_package.log
#            
##############
source ~jenkins/.bash_profile
export DISPLAY=:0
set -e

LOG_TAIL=-24


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

export MAVEN_UPLOAD_VERSION=${AND_VRSN}
export MAVEN_UPLOAD_REPO_URL=http://files.couchbase.com/maven2/

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds

AUT_DIR=${WORKSPACE}/app-under-test
if [[ -e ${AUT_DIR}  ]] ; then rm -rf ${AUT_DIR}  ; fi

ANDR_DIR=${AUT_DIR}/android
if [[ -e ${ANDR_DIR} ]] ; then rm -rf ${ANDR_DIR} ; fi
mkdir -p ${ANDR_DIR}

ANDR_LITESRV_DIR=${ANDR_DIR}/couchbase-lite-android-liteserv

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


if [[ ! -d ${MAVEN_LOCAL_REPO} ]] ; then mkdir -p ${MAVEN_LOCAL_REPO} ; fi

echo ============================================  build android
cd ${ANDR_LITESRV_DIR}
cp extra/jenkins_build/* .


echo ============================================  build android zipfile

MVN_ZIP=com.couchbase.lite-${VERSION}-android.zip
AND_ZIP=cblite_android_${REVISION}.zip

cd    ${ANDR_LITESRV_DIR}/release  &&  ./zip_jars.sh ${AND_VRSN} ${WORKSPACE}/android_package.log

if  [[ -e ${WORKSPACE}/android_package.log ]]
    then
    echo "===================================== ${WORKSPACE}/android_package.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${WORKSPACE}/android_package.log
fi

file  ${ANDR_LITESRV_DIR}/release/target/${MVN_ZIP} || exit 99
cp    ${ANDR_LITESRV_DIR}/release/target/${MVN_ZIP} ${WORKSPACE}/${AND_ZIP}

echo ============================================ upload ${CBFS_URL}/${AND_ZIP}
curl -XPUT --data-binary @${WORKSPACE}/${AND_ZIP} ${CBFS_URL}/${AND_ZIP}


