#!/bin/bash
#          
#          run by jenkins job 'build_sync_gateway'
#          
#          with paramter:  REVISION
#             
source ~jenkins/.bash_profile
set -e

if [[ ! ${GITSPEC} ]] ; then GITSPEC=master ; fi

UNAME_SM=`uname -sm`
if [[ ($UNAME_SM =~ Darwin)  && ($UNAME_SM =~ 64)    ]] ; then OS=darwin  ; ARCH=amd64 ; EXEC=sync_gateway     ; PKGR=package-mac.rb ; fi
if [[ ($UNAME_SM =~ Linux)   && ($UNAME_SM =~ 64)    ]] ; then OS=linux   ; ARCH=amd64 ; EXEC=sync_gateway     ; fi
if [[ ($UNAME_SM =~ Linux)   && ($UNAME_SM =~ i386)  ]] ; then OS=linux   ; ARCH=386   ; EXEC=sync_gateway     ; fi
if [[ ($UNAME_SM =~ Linux)   && ($UNAME_SM =~ i686)  ]] ; then OS=linux   ; ARCH=386   ; EXEC=sync_gateway     ; fi
if [[ ($UNAME_SM =~ CYGWIN)  && ($UNAME_SM =~ WOW64) ]] ; then OS=windows ; ARCH=amd64 ; EXEC=sync_gateway.exe ; PKGR=package-win.rb ; fi
if [[ ($UNAME_SM =~ CYGWIN)  && ($UNAME_SM =~ i686)  ]] ; then OS=windows ; ARCH=386   ; EXEC=sync_gateway.exe ; PKGR=package-win.rb ; fi
if [[ ! $OS ]] 
    then
    echo -e "\nunsupported platform:  $UNAME_SM\n"
    exit 88
fi
PLAT=${OS}-${ARCH}

UNAME_A=`uname -a`
if [[ $UNAME_A =~ centos ]] ; then PKGR=package-rpm.rb ; PKGTYPE=rpm ; fi
if [[ $UNAME_A =~ ubuntu ]] ; then PKGR=package-deb.rb ; PKGTYPE=deb ; fi
if [[ ! $PKGR ]] 
    then
    echo -e "\nunsupported platform:  $UNAME_A\n"
    exit 99
fi
PKG_NAME=couchbase-sync-gateway_${REVISION}_${ARCH}.${PKGTYPE}

env | grep -iv password | grep -iv passwd | sort -u
echo ==============================================

ZIP_FILE=sync_gateway_${REVISION}.zip
CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds

SGW_DIR=${WORKSPACE}/sync_gateway
BLD_DIR=${SGW_DIR}/build
DWNLOAD=${BLD_DIR}/download
PREFIXD=${BLD_DIR}/opt-couchbase-sync-gateway
PREFIX=/opt/couchbase-sync-gateway

cd ${WORKSPACE}
echo ======== sync sync_gateway ===================

if [[ ! -d sync_gateway ]] ; then git clone https://github.com/couchbase/sync_gateway.git ; fi
cd         sync_gateway
git pull  origin  ${GITSPEC}
git submodule init
git submodule update
git show --stat
REPO_SHA=`git log --oneline --no-abbrev-commit --pretty="format:%H" -1`

if [[ -e ${DWNLOAD} ]] ; then rm -rf ${DWNLOAD} ; fi
if [[ -e ${PREFIXD} ]] ; then rm -rf ${PREFIXD} ; fi
echo ======== build ===============================

mkdir -p ${PREFIXD}/bin/
mkdir -p ${DWNLOAD}
cd       ${DWNLOAD}
wget --no-verbose --output-document=${ZIP_FILE}  ${CBFS_URL}/${ZIP_FILE}
unzip   ${ZIP_FILE}

cp ${PLAT}/${EXEC}         ${PREFIXD}/bin/
cp ${BLD_DIR}/LICENSE.txt  ${PREFIXD}
cp ${BLD_DIR}/README.txt   ${PREFIXD}
echo ${REVISION}         > ${PREFIXD}/VERSION.txt

echo ======== package =============================

cd ${BLD_DIR}
./${PKGR} ${PREFIX} ${PREFIXD} ${REVISION} ${REPO_SHA}

cp ${BLD_DIR}/build/deb/${PKG_NAME}  ${SGW_DIR}
cd ${SGW_DIR}

echo  ======= upload ==============================
echo ................... uploading to ${CBFS_URL}/${PKG_NAME}
curl -XPUT --data-binary @${PKG_NAME} ${CBFS_URL}/${PKG_NAME}

