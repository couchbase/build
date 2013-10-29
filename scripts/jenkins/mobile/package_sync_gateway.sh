#!/bin/bash
#          
#          run by jenkins job 'package_sync_gateway'
#          
#          with required paramters:
#         
#             REVISION  -- build number (e.g. 1.0-280) whose artifacts are to be packaged
#             
#             GITSPEC   -- sync_gateway revision that triggered that build.  can use:
#             
#                          `git log --oneline --no-abbrev-commit --pretty="format:%H" -1`
#             
source ~jenkins/.bash_profile
set -e

if [[ ! ${GITSPEC} ]] ; then GITSPEC=master ; fi

OS=`uname -s`
if [[ $OS =~ Linux  ]] ; then GOOS=linux   ; fi
if [[ $OS =~ Darwin ]] ; then GOOS=darwin  ; fi
if [[ $OS =~ CYGWIN ]] ; then GOOS=windows ; fi
if [[ ! $GOOS ]] 
    then
    echo -e "\nunsupported operating system:  $OS\n"
    exit 99
fi
ARCH=`uname -m`
if [[ $ARCH =~ 86  ]] ; then GOARCH=386   ; fi
if [[ $ARCH =~ 64  ]] ; then GOARCH=amd64 ; fi
if [[ ! $GOARCH ]] 
    then
    echo -e "\nunsupported architecture:  $ARCH\n"
    exit 88
fi
if [[ $GOOS =~ linux   ]] ; then EXEC=sync_gateway     ;                       fi
if [[ $GOOS =~ darwin  ]] ; then EXEC=sync_gateway     ; PKGR=package-mac.rb ; fi
if [[ $GOOS =~ windows ]] ; then EXEC=sync_gateway.exe ; PKGR=package-win.rb ; fi

UNAME_A=`uname -a`
if [[ $UNAME_A =~ centos ]] ; then PKGR=package-rpm.rb ; PKGTYPE=rpm
    if [[ $ARCH =~ i686  ]] ; then ARCH=i386  ; fi
fi
if [[ $UNAME_A =~ ubuntu ]] ; then PKGR=package-deb.rb ; PKGTYPE=deb
    if [[ $ARCH =~ 64    ]] ; then ARCH=amd64 ; fi
 fi
if [[ ! $PKGR ]] 
    then
    echo -e "\nunsupported platform:  $UNAME_A\n"
    exit 99
fi

GOPLAT=${GOOS}-${GOARCH}
PLATFORM=${OS}-${ARCH}

PKG_NAME=couchbase-sync-gateway_${REVISION}_${ARCH}.${PKGTYPE}

env | grep -iv password | grep -iv passwd | sort -u
echo ==============================================

ZIP_FILE=sync_gateway_${REVISION}.zip
CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds

SGW_DIR=${WORKSPACE}/sync_gateway
BLD_DIR=${SGW_DIR}/build
DWNLOAD=${BLD_DIR}/download

PREFIXD=${BLD_DIR}/opt/couchbase-sync-gateway
PREFIX=/opt/couchbase-sync-gateway
PREFIXP=./opt/couchbase-sync-gateway
                                                #  needed by ~/.rpmmacros 
                                                #  called by package-rpm.rb
                                                #
RPM_ROOT_DIR=${BLD_DIR}/build/rpm/couchbase-sync-gateway_${REVISION}/rpmbuild/
export RPM_ROOT_DIR


cd ${WORKSPACE}
echo ======== sync sync_gateway ===================
echo ======== to ${GITSPEC}

if [[ ! -d sync_gateway ]] ; then git clone https://github.com/couchbase/sync_gateway.git ; fi
cd         sync_gateway
git pull  origin  ${GITSPEC}
git submodule init
git submodule update
git show --stat

if [[ -e ${DWNLOAD} ]] ; then rm -rf ${DWNLOAD} ; fi
if [[ -e ${PREFIXD} ]] ; then rm -rf ${PREFIXD} ; fi
echo ======== build ===============================

mkdir -p ${PREFIXD}/bin/
mkdir -p ${DWNLOAD}
cd       ${DWNLOAD}
wget --no-verbose --output-document=${ZIP_FILE}  ${CBFS_URL}/${ZIP_FILE}
unzip   ${ZIP_FILE}

cp ${GOPLAT}/${EXEC}       ${PREFIXD}/bin/
cp ${BLD_DIR}/LICENSE.txt  ${PREFIXD}
cp ${BLD_DIR}/README.txt   ${PREFIXD}
echo ${REVISION}         > ${PREFIXD}/VERSION.txt

echo ======== package =============================
echo ${BLD_DIR}' => './${PKGR} ${PREFIX} ${PREFIXP} ${REVISION} ${PLATFORM} ${ARCH}
cd   ${BLD_DIR}
./${PKGR} ${PREFIX} ${PREFIXP} ${REVISION} ${GITSPEC} ${PLATFORM} ${ARCH}

echo  ======= upload ==============================
cp ${PREFIXD}/${PKG_NAME} ${SGW_DIR}
cd                        ${SGW_DIR}
echo ................... uploading to ${CBFS_URL}/${PKG_NAME}
curl -XPUT --data-binary @${PKG_NAME} ${CBFS_URL}/${PKG_NAME}

