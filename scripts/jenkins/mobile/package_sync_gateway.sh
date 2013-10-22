#!/bin/bash
#          
#          run by jenkins job 'build_sync_gateway'
#          
#          with paramter:
#              
#              REVISION
#             
source ~jenkins/.bash_profile

UNAME_SM=`uname -sm`
if [[ ($UNAME_SM =~ /darwin/i)  && ($UNAME_SM =~ /64/)    ]] ; then PLAT=darwin-amd64   ; EXEC=sync_gateway     ; PKGR=package-mac.rb ; fi
if [[ ($UNAME_SM =~ /linux/i)   && ($UNAME_SM =~ /64/)    ]] ; then PLAT=linux-amd64    ; EXEC=sync_gateway     ; fi
if [[ ($UNAME_SM =~ /linux/i)   && ($UNAME_SM =~ /i386/)  ]] ; then PLAT=linux-386      ; EXEC=sync_gateway     ; fi
if [[ ($UNAME_SM =~ /linux/i)   && ($UNAME_SM =~ /i686/)  ]] ; then PLAT=linux-386      ; EXEC=sync_gateway     ; fi
if [[ ($UNAME_SM =~ /cygwin/i)  && ($UNAME_SM =~ /WOW64/) ]] ; then PLAT=windows-amd64  ; EXEC=sync_gateway.exe ; PKGR=package-win.rb ; fi
if [[ ($UNAME_SM =~ /cygwin/i)  && ($UNAME_SM =~ /i686/)  ]] ; then PLAT=windows-386    ; EXEC=sync_gateway.exe ; PKGR=package-win.rb ; fi
if [[ ! $PLAT ]] 
    then
    echo -e "\nunsupported platform:  $UNAME_SM\n"
    exit 88
fi
UNAME_A=`uname -a`
if [[ $UNAME_A =~ /centos/i) ; then PKGR=package-rpm.rb ; fi
if [[ $UNAME_A =~ /ubuntu/i) ; then PKGR=package-deb.rb ; fi
if [[ ! $PKGR ]] 
    then
    echo -e "\nunsupported platform:  $UNAME_A\n"
    exit 99
fi

env | grep -iv password | grep -iv passwd | sort -u
echo ==============================================

ZIP_FILE=sync_gateway_${REVISION}.zip
CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds

SGW_DIR=${WORKSPACE}/sync_gateway
BLD_DIR=${SGW_DIR}/build
DWNLOAD=${BLD_DIR}/download
PREFIXD=${BLD_DIR}/opt-couchbase-sync-gateway

cd ${WORKSPACE}
echo ======== sync sync_gateway ===================

if [[ ! -d sync_gateway ]] ; then git clone https://github.com/couchbase/sync_gateway.git ; fi
cd         sync_gateway
git pull
git submodule init
git submodule update
git show --stat

if [[ -e ${BLD_DIR} ]] ; then rm -rf ${BLD_DIR} ; fi
echo ======== build ===============================

mkdir -p ${PREFIXD}/bin/
mkdir -p ${DWNLOAD}
cd       ${DWNLOAD}
wget -o ${ZIP_FILE}  ${CBFS_URL}/${ZIP_FILE}
unzip   ${ZIP_FILE}

cp ${PLAT}/${EXEC}         ${PREFIXD}/bin/
cp ${BLD_DIR}/LICENSE.txt  ${PREFIXD}
cp ${BLD_DIR}/README.txt   ${PREFIXD}
echo ${REVISION}         > ${PREFIXD}/VERSION.txt

echo ======== package =============================
PREFIX=/opt/couchbase-sync-gateway
PRODUCT=couchbase-sync-gateway
PRODUCT_BASE=couchbase
PRODUCT_KIND=sync-gateway

cd ${BLD_DIR}
./${PKGR} $(PREFIX) $(PRODUCT) $(PRODUCT_BASE) $(PRODUCT_KIND)

echo  ======= upload ==============================
echo ................... uploading to ${CBFS_URL}/
#curl -XPUT --data-binary @${ZIP_FILE} ${CBFS_URL}/${ZIP_FILE}

