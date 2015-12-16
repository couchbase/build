#!/bin/bash -ex
#          
#    run by jenkins sync_gateway jobs:
#          
#    with required paramters:
#   
#          branch_name    distro    version    bld_num    edition
#             
#    e.g.: master         centos    0.0.0      0000       community
#          release/1.1.0  macosx    1.1.0      1234       enterprise
#
#    and optional parameters:
#    
#        GO_REL    1.4.1  (non-Docker builders)
#        OS        -- `uname -s`
#        ARCH      -- `uname -m`
#          
#    This script only aupports branches 1.1.0 and newer
#
#    ErrorCode:
#        11 = Incorrect input parameters
#        22 = Unsupported DISTRO
#        33 = Unsupported OS
#        44 = Build failed
#        55 = Unit test failed
#
set -e

function usage
    {
    echo "Incorrect parameters..."
    echo -e "\nUsage:  ${0}   branch_name  distro  version  bld_num  edition  commit_sha  [ GO_REL ]\n\n"
    }

if [[ "$#" < 5 ]] ; then usage ; exit 11 ; fi

# enable nocasematch
shopt -s nocasematch

GITSPEC=${1}

DISTRO=${2}

VERSION=${3}

BLD_NUM=${4}

EDITION=${5}

if [[ $6 ]] ; then  echo "setting TEST_OPTIONS to $6"   ; TEST_OPTIONS=$6   ; else TEST_OPTIONS="None"  ; fi
if [[ $7 ]] ; then  echo "setting REPO_SHA to $7"       ; REPO_SHA=$7       ; else REPO_SHA="None"      ; fi
if [[ $8 ]] ; then  echo "setting GO_REL to $8"         ; GO_REL=$8         ; else GO_REL=1.5.2         ; fi

OS=`uname -s`
ARCH=`uname -m`

export GITSPEC ; export DISTRO ; export VERSION ; export BLD_NUM ; export EDITION
export OS ; export ARCH

if [[ $GITSPEC =~ feature  ]]
then
    LATESTBUILDS_SGW=http://latestbuilds.hq.couchbase.com/couchbase-sync-gateway/0.0.1/${GITSPEC}/${VERSION}-${BLD_NUM}
else
    LATESTBUILDS_SGW=http://latestbuilds.hq.couchbase.com/couchbase-sync-gateway/${GITSPEC}/${VERSION}-${BLD_NUM}
fi

ARCHP=${ARCH}
PARCH=${ARCHP}

if [[ $DISTRO =~ centos  ]]
then
    DISTRO="centos"
    PKGR=package-rpm.rb
    PKGTYPE=rpm
    if [[ $ARCHP =~ i686 ]] ; then ARCHP=i386  ; fi
    PLATFORM=${OS}-${ARCH}
    PKG_NAME=couchbase-sync-gateway_${VERSION}-${BLD_NUM}_${ARCHP}.${PKGTYPE}
    NEW_PKG_NAME=couchbase-sync-gateway-${EDITION}_${VERSION}-${BLD_NUM}_${PARCH}.${PKGTYPE}
    TAR_PKG_NAME=couchbase-sync-gateway-centos_${EDITION}_${VERSION}-${BLD_NUM}_${PARCH}.tar.gz
elif [[ $DISTRO =~ ubuntu  ]]
then
    DISTRO="ubuntu"
    PKGR=package-deb.rb
    PKGTYPE=deb
    if [[ $ARCHP =~ 64   ]] ; then ARCHP=amd64
                              else ARCHP=i386 ; fi
    PLATFORM=${OS}-${ARCH}
    PKG_NAME=couchbase-sync-gateway_${VERSION}-${BLD_NUM}_${ARCHP}.${PKGTYPE}
    NEW_PKG_NAME=couchbase-sync-gateway-${EDITION}_${VERSION}-${BLD_NUM}_${PARCH}.${PKGTYPE}
    TAR_PKG_NAME=couchbase-sync-gateway-ubuntu_${EDITION}_${VERSION}-${BLD_NUM}_${PARCH}.tar.gz
elif [[ $DISTRO =~ macosx  ]]
then
    PLATFORM=${DISTRO}-${ARCH}
    PKG_NAME=couchbase-sync-gateway_${VERSION}-${BLD_NUM}_${DISTRO}-${ARCH}.tar.gz
    NEW_PKG_NAME=couchbase-sync-gateway-${EDITION}_${VERSION}-${BLD_NUM}_${PARCH}.tar.gz
else
   echo -e "\nunsupported DISTRO:  $DISTRO\n"
    exit 22
fi

if [[ $OS =~ Linux  ]]
then
    GOOS=linux
    EXEC=sync_gateway
elif [[ $OS =~ Darwin ]]
then
    GOOS=darwin
    EXEC=sync_gateway
    PKGR=package-mac.rb
else
    echo -e "\nunsupported operating system:  $OS\n"
    exit 33
fi

export GOOS ; export EXEC

if [[ $ARCH =~ 64  ]] ; then GOARCH=amd64
                        else GOARCH=386   ; fi

# disable nocasematch
shopt -u nocasematch

if [[ $ARCHP =~ i386  ]] ; then PARCH=x86
elif [[ $ARCHP =~ amd64 ]] ; then PARCH=x86_64 ; fi

GOPLAT=${GOOS}-${GOARCH}

# Require for builds not using Docker
GO_RELEASE=${GO_REL}
if [ -d /usr/local/go/${GO_RELEASE} ]
then
    GOROOT=/usr/local/go/${GO_RELEASE}/go
else
    echo -e "\nNeed to specify correct GOLANG version: 1.4.1 or 1.5.2\n"
    exit 1
fi

PATH=${PATH}:${GOROOT}/bin

export GO_RELEASE ; export GOROOT ; export PATH

echo "Running GO version ${GO_RELEASE}"
go version

env | grep -iv password | grep -iv passwd | sort -u
echo ============================================== `date`

TARGET_DIR=${WORKSPACE}/${GITSPEC}/${EDITION}
LIC_DIR=${TARGET_DIR}/build/license/sync_gateway
AUT_DIR=${TARGET_DIR}/app-under-test
SGW_DIR=${AUT_DIR}/sync_gateway
BLD_DIR=${SGW_DIR}/build

PREFIX=/opt/couchbase-sync-gateway
PREFIXP=./opt/couchbase-sync-gateway
STAGING=${BLD_DIR}/opt/couchbase-sync-gateway

if [[ -e ${PREFIX}  ]] ; then sudo rm -rf ${PREFIX}  ; fi
if [[ -e ${STAGING} ]] ; then      rm -rf ${STAGING} ; fi

                                                #  needed by ~/.rpmmacros 
                                                #  called by package-rpm.rb
                                                #
RPM_ROOT_DIR=${BLD_DIR}/build/rpm/couchbase-sync-gateway_${VERSION}-${BLD_NUM}/rpmbuild/
export RPM_ROOT_DIR

if [[ ! -d ${AUT_DIR} ]] ; then  mkdir -p ${AUT_DIR} ; fi
cd         ${AUT_DIR}
echo ======== sync sync_gateway ===================
pwd
if [[ ! -d sync_gateway ]] ; then git clone https://github.com/couchbase/sync_gateway.git ; fi
cd         sync_gateway

# master branch maps to "0.0.0" for backward compatibility with pre-existing jobs 
if [[ ${GITSPEC} =~ "0.0.0" ]]
then
    BRANCH=master
else
    BRANCH=${GITSPEC}
    git checkout --track -B ${BRANCH} origin/${BRANCH}
fi
if [ ${REPO_SHA} == "None" ]
then
    git pull origin ${BRANCH}
else
    git checkout ${REPO_SHA}
fi

git submodule init
git submodule update
git show --stat

if [[ ! -d ${STAGING}/bin/      ]] ; then mkdir -p ${STAGING}/bin/      ; fi
if [[ ! -d ${STAGING}/examples/ ]] ; then mkdir -p ${STAGING}/examples/ ; fi
if [[ ! -d ${STAGING}/service/  ]] ; then mkdir -p ${STAGING}/service/  ; fi

REPO_SHA=`git log --oneline --pretty="format:%H" -1`

#
# Does not support releases 1.0.4 and older due to move from couchbaselab to couchbase
#
TEMPLATE_FILES="src/github.com/couchbase/sync_gateway/rest/api.go"

echo ======== insert build meta-data ==============
for TF in ${TEMPLATE_FILES}
  do
    cat ${TF} | sed -e "s,@PRODUCT_VERSION@,${VERSION}-${BLD_NUM},g" \
              | sed -e "s,@COMMIT_SHA@,${REPO_SHA},g"      > ${TF}.new
    mv  ${TF}      ${TF}.orig
    mv  ${TF}.new  ${TF}
done

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
# 
# RANDOM in 1..32767

#let STARTUP_DELAY=30+${RANDOM}/1000
# Decrease to 1 sec to observe connection issue.  If no issue, then remove
let STARTUP_DELAY=1
sleep ${STARTUP_DELAY}
echo ======== D O N E   S L E E P ================= `date`

# ... caused by all builders running at once

# clean up stale objects switching between GO version
if [[ -d ${SGW_DIR}/pkg ]]
then
    rm -rf ${SGW_DIR}/pkg
fi

#
# Does not support releases 1.0.4 and older due to move from couchbaselab to couchbase
#
GOOS=${GOOS} GOARCH=${GOARCH} go build -v github.com/couchbase/sync_gateway

if [[ -e ${SGW_DIR}/${EXEC} ]]
  then
    mv   ${SGW_DIR}/${EXEC} ${DEST_DIR}
    echo "..............................Success! Output is: ${DEST_DIR}/${EXEC}"
  else
    echo "############################# FAIL! no such file: ${DEST_DIR}/${EXEC}"
    exit 44
fi

echo ======== remove build meta-data ==============
for TF in ${TEMPLATE_FILES}
  do
    mv  ${TF}.orig ${TF}
done

echo ======== test ================================ `date`
echo ........................ running test.sh
if [[ ${TEST_OPTIONS} =~ "None" ]]
then
    ./test.sh
else
    ./test.sh ${TEST_OPTIONS} 
fi

test_result=$?
if [ ${test_result} -ne "0" ]
then
    echo "########################### FAIL! Unit test results = ${test_result}"
    exit 55
fi

echo ======== package =============================
cp    ${DEST_DIR}/${EXEC}                ${STAGING}/bin/
cp    ${BLD_DIR}/README.txt              ${STAGING}
echo  ${VERSION}-${BLD_NUM}            > ${STAGING}/VERSION.txt
cp    ${LIC_DIR}/LICENSE_${EDITION}.txt  ${STAGING}/LICENSE.txt
cp -r ${SGW_DIR}/examples                ${STAGING}
cp -r ${SGW_DIR}/service                 ${STAGING}

echo ${BLD_DIR}' => ' ./${PKGR} ${PREFIX} ${PREFIXP} ${VERSION}-${BLD_NUM} ${REPO_SHA} ${PLATFORM} ${ARCHP}
cd   ${BLD_DIR}   ;   ./${PKGR} ${PREFIX} ${PREFIXP} ${VERSION}-${BLD_NUM} ${REPO_SHA} ${PLATFORM} ${ARCHP}

echo  ======= upload ==============================
cp ${STAGING}/${PKG_NAME} ${SGW_DIR}/${NEW_PKG_NAME}

if [[ $DISTRO =~ centos  ]] || [[ $DISTRO =~ ubuntu  ]]
  then
    cd ${STAGING}
    rm -f ${PKG_NAME}
    tar cvfz ${TAR_PKG_NAME} * 
    cp ${TAR_PKG_NAME} ${SGW_DIR}
fi

cd                        ${SGW_DIR}
if [[ $DISTRO =~ macosx ]]
then
    md5 ${NEW_PKG_NAME}  > ${NEW_PKG_NAME}.md5
else
    md5sum ${NEW_PKG_NAME}  > ${NEW_PKG_NAME}.md5
fi
sleep ${STARTUP_DELAY}
echo ======== D O N E   S L E E P ================= `date`

echo -------........................... uploading internally to ${LATESTBUILDS_SGW}/${NEW_PKG_NAME}

echo ============================================== `date`
