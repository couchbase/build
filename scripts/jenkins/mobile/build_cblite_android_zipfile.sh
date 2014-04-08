#!/bin/bash
#          
#          run by jenkins jobs: 'build_cblite_android_master'
#                               'build_cblite_android_stable'
#          
#          and called with paramters:         branch_name  release_number   build_number_of
#          
#            by build_cblite_android_master:     master         0.0.0     build_cblite_android_master
#            by build_cblite_android_stable:     stable         1.0.0     build_cblite_android_stable
#            by build_cblite_android_100:        release/1.0.0  1.0.0     build_cblite_android_100
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
    echo -e "\nuse:  ${0}   branch_name  release_number  build_number\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
RELEASE=${2}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
BLD_NUM=${3}

REVISION=${RELEASE}-${BLD_NUM}
AND_VRSN=${RELEASE}.${BLD_NUM}

AUT_DIR=${WORKSPACE}/app-under-test
if [[ -e ${AUT_DIR}  ]] ; then rm -rf ${AUT_DIR}  ; fi

ANDR_DIR=${AUT_DIR}/android
if [[ -e ${ANDR_DIR} ]] ; then rm -rf ${ANDR_DIR} ; fi
mkdir -p ${ANDR_DIR}

ANDR_LITESRV_DIR=${ANDR_DIR}/couchbase-lite-android-liteserv

export MAVEN_CBASE_REPO=http://files.couchbase.com/maven2/
export MAVEN_LOCAL_REPO=${ANDR_LITESRV_DIR}/release/m2

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds

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


echo ============================================  build android zipfile

if [[ ! -d ${MAVEN_LOCAL_REPO} ]] ; then mkdir -p ${MAVEN_LOCAL_REPO} ; fi

MVN_ZIP=couchbase-lite-${AND_VRSN}-android.zip
#AND_ZIP=cblite_android_${REVISION}.zip
rm -f                                                            ${WORKSPACE}/android_package.log
cd    ${ANDR_LITESRV_DIR}/release  &&  ./zip_jars.sh ${AND_VRSN} ${WORKSPACE}/android_package.log

if  [[ -e ${WORKSPACE}/android_package.log ]]
    then
    echo "===================================== ${WORKSPACE}/android_package.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${WORKSPACE}/android_package.log
fi

file  ${ANDR_LITESRV_DIR}/release/target/${MVN_ZIP} || exit 99
cp    ${ANDR_LITESRV_DIR}/release/target/${MVN_ZIP} ${WORKSPACE}/${MVN_ZIP}

echo ============================================ upload ${CBFS_URL}/${MVN_ZIP}
curl -XPUT --data-binary @${WORKSPACE}/${MVN_ZIP} ${CBFS_URL}/${MVN_ZIP}

