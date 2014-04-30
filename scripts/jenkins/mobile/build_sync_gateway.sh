#!/bin/bash
#          
#    run by jenkins jobs:
#          
#        build_sync_gateway_master_<platform>
#        build_sync_gateway_100_<platform>
#        build_sync_gateway_stable_<platform>
#          
#    with required paramters:
#   
#          branch_name    version     platform   Edition
#             
#    e.g.: master         0.0.0-0000  centos-x86   community
#          release/1.0.0  1.0.0-1234  centos-x64   enterprise
#          stable         0000000000  ubuntu-x86
#                                     ubutnu-x64
#                                     macosx-x64
#    and optional parameters:
#    
#        OS        -- `uname -s`
#        ARCH      -- `uname -m`
#        DISTRO    -- `uname -a`
#          
source ~/.bash_profile
set -e

CURL_CMD="curl --fail --retry 10 --silent --show-error"


function usage
    {
    echo -e "\nuse:  ${0}   branch_name  version  platform  edition  [ OS ]  [ ARCH ]  [ DISTRO ]\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
VERSION=${2}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
PLATFRM=${3}

if [[ ! ${4} ]] ; then usage ; exit 66 ; fi
EDITION=${4}

export GITSPEC ; export VERSION ; export PLATFRM ; export EDITION

LAST_GOOD_PARAM=SYNCGATE_VERSION_`echo ${PLATFRM} | tr '-' '_' | tr [a-z] [A-Z]`

if [[ $5 ]] ; then  echo "setting OS     to $OS"        ; OS=$5     ; else OS=`uname -s`     ; fi
if [[ $6 ]] ; then  echo "setting ARCH   to $ARCH"      ; ARCH=$6   ; else ARCH=`uname -m`   ; fi
if [[ $7 ]] ; then  echo "setting DISTRO to $DISTRO"    ; DISTRO=$7 ; else DISTRO=`uname -a` ; fi

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

ARCHP=${ARCH}

if [[ $DISTRO =~ centos  ]] ; then PKGR=package-rpm.rb ; PKGTYPE=rpm
    if [[ $ARCHP =~ i686 ]] ; then ARCHP=i386  ; fi
fi
if [[ $DISTRO =~ ubuntu  ]] ; then PKGR=package-deb.rb ; PKGTYPE=deb
    if [[ $ARCHP =~ 64   ]] ; then ARCHP=amd64
                              else ARCHP=i386  ; fi
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
                              NEW_PKG_NAME=${PKG_NAME}
if [[ ${EDITION} =~ community ]]
    then
                              NEW_PKG_NAME=couchbase-sync-gateway_${VERSION}_${ARCHP}-${EDITION}.${PKGTYPE}
fi
if [[ $DISTRO =~ macosx ]]
    then
    PLATFORM=${DISTRO}-${ARCH}
                                  PKG_NAME=couchbase-sync-gateway_${VERSION}_${DISTRO}-${ARCH}.tar.gz
                              NEW_PKG_NAME=${PKG_NAME}
    if [[ ${EDITION} =~ community ]]
        then
                              NEW_PKG_NAME=couchbase-sync-gateway_${VERSION}_${DISTRO}-${ARCH}-${EDITION}.tar.gz
    fi
fi

export GOOS ; export EXEC

GO_RELEASE=1.2
GOROOT=/usr/local/go/${GO_RELEASE}

PATH=${PATH}:${GOROOT}/bin 

export GO_RELEASE ; export GOROOT ; export PATH

env | grep -iv password | grep -iv passwd | sort -u
echo ============================================== `date`

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds

pushd ${WORKSPACE} 2>&1 > /dev/null
WORKSPACE=`pwd`
popd               2>&1 > /dev/null
LIC_DIR=${WORKSPACE}/build/license/sync_gateway
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

TEMPLATE_FILES="src/github.com/couchbaselabs/sync_gateway/rest/api.go"

echo ======== insert build meta-data ==============
for TF in ${TEMPLATE_FILES}
  do
    cat ${TF} | sed -e "s,@PRODUCT_VERSION@,${VERSION},g" \
              | sed -e "s,@COMMIT_SHA@,${REPO_SHA},g"      > ${TF}.new
    mv  ${TF}      ${TF}.orig
    mv  ${TF}.new  ${TF}
done


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


# prevent connection timed out:  https://google.com: dial tcp 74.125.239.97:443...

let STARTUP_DELAY=3+${RANDOM}/6552
sleep ${STARTUP_DELAY}

# ... caused by all builders running at once


GOOS=${GOOS} GOARCH=${GOARCH} go build -v github.com/couchbaselabs/sync_gateway
if [[ -e ${SGW_DIR}/${EXEC} ]]
  then
    mv   ${SGW_DIR}/${EXEC} ${DEST_DIR}
    echo "..............................Success! Output is: ${DEST_DIR}/${EXEC}"
  else
    echo "############################# FAIL! no such file: ${DEST_DIR}/${EXEC}"
fi

echo ======== remove build meta-data ==============
for TF in ${TEMPLATE_FILES}
  do
    mv  ${TF}.orig ${TF}
done

echo ======== test ================================
echo ........................ running test.sh
                                ./test.sh

echo ======== package =============================
cp ${DEST_DIR}/${EXEC}                ${PREFIXD}/bin/
cp ${BLD_DIR}/README.txt              ${PREFIXD}
echo ${VERSION}                     > ${PREFIXD}/VERSION.txt
cp ${LIC_DIR}/LICENSE_${EDITION}.txt  ${PREFIXD}/LICENSE.txt

echo ${BLD_DIR}' => ' ./${PKGR} ${PREFIX} ${PREFIXP} ${VERSION} ${REPO_SHA} ${PLATFORM} ${ARCHP}
cd   ${BLD_DIR}   ;   ./${PKGR} ${PREFIX} ${PREFIXP} ${VERSION} ${REPO_SHA} ${PLATFORM} ${ARCHP}

echo  ======= upload ==============================
cp ${PREFIXD}/${PKG_NAME} ${SGW_DIR}/${NEW_PKG_NAME}
cd                        ${SGW_DIR}
md5sum ${NEW_PKG_NAME}  > ${NEW_PKG_NAME}.md5
echo        ........................... uploading to ${CBFS_URL}/${NEW_PKG_NAME}
${CURL_CMD} -XPUT --data-binary @${NEW_PKG_NAME}     ${CBFS_URL}/${NEW_PKG_NAME}
${CURL_CMD} -XPUT --data-binary @${NEW_PKG_NAME}.md5 ${CBFS_URL}/${NEW_PKG_NAME}.md5

echo ============================================== `date`
