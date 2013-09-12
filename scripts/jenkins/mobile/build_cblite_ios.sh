#!/bin/bash
#          
#          run by jenkins job 'build_cblite_ios'
#          
#          with no paramters
#          
VERSION=1.0

REVISION=${VERSION}-${BUILD_NUMBER}

LOG_FILE=/Users/couchbase/jenkins/workspace/build_cblite_ios/build_ios_results.log
if [[ -e ${LOG_FILE} ]] ; then rm -f ${LOG_FILE} ; fi

ZIP_FILE=cblite_ios_${REVISION}.zip

BASE_DIR=/Users/couchbase/buildbox/couchbase-lite-ios
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

# ============================================== build
if [[ -e ${BUILDDIR} ]] ; then rm -rf ${BUILDDIR} ; fi
mkdir -p ${BUILDDIR}

cd /Users/couchbase/buildbox/couchbase-lite-ios
git pull
git submodule update
cd /Users/couchbase/buildbox/cblite-build
git pull
git show --stat

/usr/local/bin/node buildios.js | tee ${LOG_FILE}

# ============================================== package
if [[ -e ${ZIP_SRCD} ]] ; then rm -rf ${ZIP_SRCD} ; fi
mkdir -p ${ZIP_SRCD}

cp -r    ${RIO_SRCD}/*         ${RIO_DEST}
cp -r    ${REL_SRCD}/LiteServ* ${REL_DEST}
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

# ============================================== upload
curl -XPUT --data-binary @${ZIP_PATH} ${CBFS_URL}/${ZIP_FILE}

# ============================================== test

