#!/bin/bash
#          
#    run by jenkins jobs:
#          
#        build_sync_gateway_master_<platform>
#        build_sync_gateway_stable_<platform>
#          
#    with required paramters:  branch_name  release number  platform
#             
#                     e.g.:     master         0.0       centos-x86, centos-x64,
#                     e.g.:     stable         1.0       ubuntu-x86, ubutnu-x64,
#                                                                    macosx-x64
#    and optional parameters:
#    
#        OS        -- `uname -s`
#        ARCH      -- `uname -m`
#        DISTRO    -- `uname -a`
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

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
PLATFRM=${3}

if [[ $4 ]] ; then  echo "setting OS     to $OS"        ; OS=$4     ; else OS=`uname -s`     ; fi
if [[ $5 ]] ; then  echo "setting ARCH   to $ARCH"      ; ARCH=$5   ; else ARCH=`uname -m`   ; fi
if [[ $6 ]] ; then  echo "setting DISTRO to $DISTRO"    ; DISTRO=$6 ; else DISTRO=`uname -a` ; fi

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
if [[ $GOOS =~ windows ]] ; then EXEC=sync_gateway.exe ; PKGR=package-win.rb ; fi

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

cd ${WORKSPACE}
echo ======== sync sync_gateway ===================

if [[ ! -d sync_gateway ]] ; then git clone https://github.com/couchbase/sync_gateway.git ; fi
cd         sync_gateway
git pull  origin  ${GITSPEC}
git submodule init
git submodule update
git show --stat

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

echo ======== package =============================

pushd  ${SGW_DIR}/bin  2>&1 >/dev/null
zip -r ${ZIP_FILE} *
echo  ======= upload ==============================
echo ................... uploading to ${CBFS_URL}/${ZIP_FILE}
curl -XPUT --data-binary @${ZIP_FILE} ${CBFS_URL}/${ZIP_FILE}

popd                   2>&1 >/dev/null

echo  ============================================== update default value of test jobs
${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl  -j mobile_functional_tests_ios_${GITSPEC}      -p SYNCGATE_VERSION  -v ${BUILD_NUMBER}
${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl  -j mobile_functional_tests_android_${GITSPEC}  -p SYNCGATE_VERSION  -v ${BUILD_NUMBER}

