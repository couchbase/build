#!/bin/bash
#          
#          run by jenkins jobs 'build_cblite_ios_master', 'build_cblite_ios_stable'
#          
#          with paramters:  branch_name  release number
#          
#                 e.g.:     master         0.0
#                 e.g.:     stable         1.0
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

LOG_FILE=${WORKSPACE}/build_ios_results.log
if [[ -e ${LOG_FILE} ]] ; then rm -f ${LOG_FILE} ; fi

ZIP_FILE=cblite_ios_${REVISION}.zip

BASE_DIR=${WORKSPACE}/couchbase-lite-ios
BUILDDIR=${BASE_DIR}/build

ZIP_PATH=${BASE_DIR}/${ZIP_FILE}
ZIP_SRCD=${BASE_DIR}/zipfile_staging

README_D=${BASE_DIR}
README_F=${README_D}/README.md
RME_DEST=${ZIP_SRCD}

LICENSED=${BASE_DIR}/release
LICENSEF=${LICENSED}/LICENSE.txt
LIC_DEST=${ZIP_SRCD}

RIO_SRCD=${BUILDDIR}/Release-ios-universal
RIO_DEST=${ZIP_SRCD}

REL_SRCD=${BUILDDIR}/Release
REL_DEST=${ZIP_SRCD}

LIB_SRCD=${BUILDDIR}/Release-CBLJSViewCompiler-ios-universal
LIB_SRCF=${LIB_SRCD}/libCBLJSViewCompiler.a
LIB_DEST=${ZIP_SRCD}/Extras

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds

export TAP_TIMEOUT=120

echo ============================================
env | grep -iv password | grep -iv passwd | sort

cd ${WORKSPACE}
echo ============================================  sync couchbase-lite-ios
echo ============================================  to ${GITSPEC}

if [[ ! -d couchbase-lite-ios ]] ; then git clone https://github.com/couchbase/couchbase-lite-ios.git ; fi
cd  couchbase-lite-ios
git checkout      ${GITSPEC}
git pull  origin  ${GITSPEC}
git submodule init
git submodule update
git show --stat

cd ${WORKSPACE}
echo ============================================  sync cblite-build
echo ============================================  to master

if [[ ! -d cblite-build ]] ; then git clone https://github.com/couchbaselabs/cblite-build.git ; fi
cd  cblite-build
git checkout      master
git pull  origin  master
git submodule init
git submodule update
git show --stat

/usr/local/bin/node buildios.js --iosrepo ${WORKSPACE}/couchbase-lite-ios | tee ${LOG_FILE}

echo  ============================================== package ${ZIP_FILE}
if [[ -e ${ZIP_SRCD} ]] ; then rm -rf ${ZIP_SRCD} ; fi
mkdir -p ${ZIP_SRCD}

cp  -r   ${RIO_SRCD}/*         ${RIO_DEST}
#cp -r   ${REL_SRCD}/LiteServ* ${REL_DEST}
cp       ${LIB_SRCF}           ${LIB_DEST}
cp       ${README_F}           ${RME_DEST}
cp       ${LICENSEF}           ${LIC_DEST}

cd       ${ZIP_SRCD}/CouchbaseLite.framework
rm -rf PrivateHeaders

cd       ${ZIP_SRCD}
rm -rf CouchbaseLite.framework.dSYM
rm -rf CouchbaseLiteListener.framework.dSYM

cd       ${ZIP_SRCD}
zip -r   ${ZIP_PATH} *

echo  ============================================== upload ${CBFS_URL}/${ZIP_FILE}
curl -XPUT --data-binary @${ZIP_PATH} ${CBFS_URL}/${ZIP_FILE}

echo  ============================================== test

