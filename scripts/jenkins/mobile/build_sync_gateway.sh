#!/bin/bash
#          
#    run by jenkins jobs:
#          
#        build_sync_gateway_master_<platform>
#        build_sync_gateway_stable_<platform>
#          
#    with required paramters:  branch_name    version   platform
#             
#                     e.g.:     master       0.0-0000  centos-x86, centos-x64,
#                     e.g.:     stable       1.0-1234  ubuntu-x86, ubutnu-x64,
#                                                                  macosx-x64
#    and optional parameters:
#    
#        OS        -- `uname -s`
#        ARCH      -- `uname -m`
#        DISTRO    -- `uname -a`
#          
source ~/.bash_profile
set -e

function usage
    {
    echo -e "\nuse:  ${0}   branch_name  version  platform\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
VERSION=${2}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
PLATFRM=${3}

export GITSPEC ; export VERSION ; export PLATFRM

if [[ $4 ]] ; then  echo "setting OS     to $OS"        ; OS=$4     ; else OS=`uname -s`     ; fi
if [[ $5 ]] ; then  echo "setting ARCH   to $ARCH"      ; ARCH=$5   ; else ARCH=`uname -m`   ; fi
if [[ $6 ]] ; then  echo "setting DISTRO to $DISTRO"    ; DISTRO=$6 ; else DISTRO=`uname -a` ; fi

if [[ $DISTRO =~ Darwin ]] ; then DISTRO="macosx"  ; fi
if [[ $DISTRO =~ CYGWIN ]] ; then DISTRO="windows" ; fi

export OS ; export ARCH ; export DISTRO

if [[ $OS =~ Linux  ]] ; then GOOS=linux   ; EXEC=sync_gateway     ; fi
if [[ $OS =~ Darwin ]] ; then GOOS=darwin  ; EXEC=sync_gateway     ; fi
if [[ $OS =~ CYGWIN ]] ; then GOOS=windows ; EXEC=sync_gateway.exe ; fi
if [[ ! $GOOS ]] 
    then
    echo -e "\nunsupported operating system:  $OS\n"
    exit 666
fi
if [[ $ARCH =~ 64  ]] ; then GOARCH=amd64
                        else GOARCH=386   ; fi

if [[ $GOOS =~ linux   ]] ; then EXEC=sync_gateway     ;                       fi
if [[ $GOOS =~ darwin  ]] ; then EXEC=sync_gateway     ; PKGR=package-mac.rb ; fi

if [[ $DISTRO =~ centos  ]] ; then PKGR=package-rpm.rb ; PKGTYPE=rpm
    if [[ $ARCH =~ i686  ]] ; then ARCH=i386   ; fi
fi

ARCHP=${ARCH}
if [[ $DISTRO =~ ubuntu  ]] ; then PKGR=package-deb.rb ; PKGTYPE=deb
    if [[ $ARCHP =~ 64   ]] ; then ARCHP=amd64
                             else ARCHP=i386   ; fi
fi
if [[ $GOOS =~ windows   ]] ; then PKGR=package-win.rb ; PKGTYPE=exe
    if [[ $ARCHP =~ i686 ]] ; then ARCHP=x86   ; fi
fi
if [[ ! $PKGR ]] 
    then
    echo -e "\nunsupported platform:  $DISTRO\n"
    exit 666
fi

GOPLAT=${GOOS}-${GOARCH}
PLATFORM=${OS}-${ARCH}
                                  PKG_NAME=couchbase-sync-gateway_${VERSION}_${ARCHP}.${PKGTYPE}
if [[ $DISTRO =~ macosx ]] ; then PKG_NAME=couchbase-sync-gateway_${VERSION}_${DISTRO}-${ARCH}.tar.gz
                                                                     PLATFORM=${DISTRO}-${ARCH}         ; fi

export GOOS ; export EXEC

GO_RELEASE=1.2
GOROOT=/usr/local/go/${GO_RELEASE}
PATH=${PATH}:${GOROOT}/bin 

export GO_RELEASE ; export GOROOT ; export PATH

env | grep -iv password | grep -iv passwd | sort -u
echo ============================================== `date`

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds

BLD_DIR=${WORKSPACE}/build
SGW_DIR=${WORKSPACE}/sync_gateway
BLD_DIR=${SGW_DIR}/build

PREFIXD=${BLD_DIR}/opt/couchbase-sync-gateway
PREFIX=/opt/couchbase-sync-gateway
PREFIXP=./opt/couchbase-sync-gateway
                                                #  needed by ~/.rpmmacros 
                                                #  called by package-rpm.rb
                                                #
RPM_ROOT_DIR=${BLD_DIR}/build/rpm/couchbase-sync-gateway_${VERSION}/rpmbuild/
export RPM_ROOT_DIR

cd ${WORKSPACE}
echo ======== sync sync_gateway ===================

if [[ ! -d sync_gateway ]] ; then git clone https://github.com/couchbase/sync_gateway.git ; fi
cd         sync_gateway
git checkout      ${GITSPEC}
git pull  origin  ${GITSPEC}
git submodule init
git submodule update
git show --stat
REPO_SHA=`git log --oneline --pretty="format:%H" -1`

if [[ -e ${PREFIXD} ]] ; then rm -rf ${PREFIXD} ; fi
mkdir -p ${PREFIXD}/bin/

cd ${SGW_DIR}
echo ======== build ===============================
rm -rf bin
echo .................. ${PLAT_DIR}
DEST_DIR=${SGW_DIR}/bin/${PLAT_DIR}
mkdir -p ${DEST_DIR}

GOPATH=${SGW_DIR}:${SGW_DIR}/vendor
export GOPATH
export CGO_ENABLED=1

GOOS=${GOOS} GOARCH=${GOARCH} go build -v github.com/couchbaselabs/sync_gateway
if [[ -e ${SGW_DIR}/${EXEC} ]]
  then
    mv   ${SGW_DIR}/${EXEC} ${DEST_DIR}
    echo "..............................Success! Output is: ${DEST_DIR}/${EXEC}"
  else
    echo "############################# FAIL! no such file: ${DEST_DIR}/${EXEC}"
fi

echo ======== test ================================
echo .................... running test.sh
                                ./test.sh

cp ${DEST_DIR}/${EXEC}     ${PREFIXD}/bin/
cp ${BLD_DIR}/LICENSE.txt  ${PREFIXD}
cp ${BLD_DIR}/README.txt   ${PREFIXD}
echo ${VERSION}          > ${PREFIXD}/VERSION.txt

echo ======== package =============================
echo ${BLD_DIR}' => ' ./${PKGR} ${PREFIX} ${PREFIXP} ${VERSION} ${REPO_SHA} ${PLATFORM} ${ARCHP}
cd   ${BLD_DIR}
./${PKGR} ${PREFIX} ${PREFIXP} ${VERSION} ${REPO_SHA} ${PLATFORM} ${ARCHP}

echo  ======= upload ==============================
cp ${PREFIXD}/${PKG_NAME} ${SGW_DIR}
cd                        ${SGW_DIR}
md5sum ${PKG_NAME} > ${PKG_NAME}.md5
echo ....................... uploading to ${CBFS_URL}/${PKG_NAME}
curl -XPUT --data-binary @${PKG_NAME}     ${CBFS_URL}/${PKG_NAME}
curl -XPUT --data-binary @${PKG_NAME}.md5 ${CBFS_URL}/${PKG_NAME}.md5

echo  ============================================== update default value of test jobs
#${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl  -j build_cblite_android_${GITSPEC}             -p SYNCGATE_VERSION  -v ${BUILD_NUMBER}

#${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl  -j mobile_functional_tests_ios_${GITSPEC}      -p SYNCGATE_VERSION  -v ${BUILD_NUMBER}
#${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl  -j mobile_functional_tests_android_${GITSPEC}  -p SYNCGATE_VERSION  -v ${BUILD_NUMBER}
echo DISABLED

