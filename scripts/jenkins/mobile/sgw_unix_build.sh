#!/bin/bash -ex
#
#    run by jenkins sync_gateway jobs for version 1.3.0 and newer:
#
#    with required paramters:
#
#          distro    version    bld_num    edition    REPO_SHA
#
#    e.g.: centos    0.0.0      0000       community    REPO_SHA
#          macosx    1.1.0      1234       enterprise   REPO_SHA
#
#    and optional parameters:
#
#        TEST_OPTIONS       `-race 4 -cpu`
#        GO_REL             1.5.3 (Currently supports 1.4.1, 1.5.2, 1.5.3)
#
#    This script supports building branches 1.3.0 and newer that uses repo manifest.
#    It will purely perform these 2 tasks:
#        - build the executable
#        - package the final binary installer
#
#    ErrorCode:
#        11 = Incorrect input parameters
#        22 = Unsupported DISTRO
#        33 = Unsupported OS
#        44 = Unsupported GO version
#        55 = Build sync_gateway failed
#        56 = Build sg_accel failed
#        66 = Unit test failed
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

DISTRO=${1}

VERSION=${2}

BLD_NUM=${3}

EDITION=${4}

REPO_SHA=${5}

if [[ $6 ]] ; then  echo "setting TEST_OPTIONS to $6"   ; TEST_OPTIONS=$6   ; else TEST_OPTIONS="None"  ; fi
if [[ $7 ]] ; then  echo "setting GO_REL to $7"         ; GO_REL=$7         ; else GO_REL=1.5.3         ; fi

OS=`uname -s`
ARCH=`uname -m`

export DISTRO ; export VERSION ; export BLD_NUM ; export EDITION
export OS ; export ARCH

ARCHP=${ARCH}
PARCH=${ARCHP}

SG_PRODUCT_NAME="Couchbase Sync Gateway"
ACCEL_PRODUCT_NAME="Couchbase SG Accel"

EXEC=sync_gateway
ACCEL_EXEC=sg_accel
ACCEL_NAME=sg-accel
COLLECTINFO_NAME=sgcollect_info

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
    ACCEL_PKG_NAME=couchbase-${ACCEL_NAME}_${VERSION}-${BLD_NUM}_${ARCHP}.${PKGTYPE}
    ACCEL_NEW_PKG_NAME=couchbase-${ACCEL_NAME}-${EDITION}_${VERSION}-${BLD_NUM}_${PARCH}.${PKGTYPE}
    ACCEL_TAR_PKG_NAME=couchbase-${ACCEL_NAME}-centos_${EDITION}_${VERSION}-${BLD_NUM}_${PARCH}.tar.gz
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
    ACCEL_PKG_NAME=couchbase-${ACCEL_NAME}_${VERSION}-${BLD_NUM}_${ARCHP}.${PKGTYPE}
    ACCEL_NEW_PKG_NAME=couchbase-${ACCEL_NAME}-${EDITION}_${VERSION}-${BLD_NUM}_${PARCH}.${PKGTYPE}
    ACCEL_TAR_PKG_NAME=couchbase-${ACCEL_NAME}-ubuntu_${EDITION}_${VERSION}-${BLD_NUM}_${PARCH}.tar.gz
elif [[ $DISTRO =~ macosx  ]]
then
    PLATFORM=${DISTRO}-${ARCH}
    PKG_NAME=couchbase-sync-gateway_${VERSION}-${BLD_NUM}_${DISTRO}-${ARCH}.tar.gz
    NEW_PKG_NAME=couchbase-sync-gateway-${EDITION}_${VERSION}-${BLD_NUM}_${PARCH}.tar.gz
    ACCEL_PKG_NAME=couchbase-${ACCEL_NAME}_${VERSION}-${BLD_NUM}_${DISTRO}-${ARCH}.tar.gz
    ACCEL_NEW_PKG_NAME=couchbase-${ACCEL_NAME}-${EDITION}_${VERSION}-${BLD_NUM}_${PARCH}.tar.gz
else
   echo -e "\nunsupported DISTRO:  $DISTRO\n"
    exit 22
fi

if [[ $OS =~ Linux  ]]
then
    GOOS=linux
elif [[ $OS =~ Darwin ]]
then
    GOOS=darwin
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

# Latest default GO version is 1.5.3
GO_RELEASE=${GO_REL}
if [ -d /usr/local/go/${GO_RELEASE} ]
then
    GOROOT=/usr/local/go/${GO_RELEASE}/go
else
    echo -e "\nNeed to specify correct GOLANG version: 1.4.1, 1.5.2, or 1.5.3\n"
    exit 44
fi

PATH=${PATH}:${GOROOT}/bin

export GO_RELEASE ; export GOROOT ; export PATH

echo "Running GO version ${GO_RELEASE}"
go version

env | sort -u
echo ============================================== `date`

TARGET_DIR=${WORKSPACE}/${VERSION}/${EDITION}
BIN_DIR=${WORKSPACE}/${VERSION}/${EDITION}/godeps/bin
LIC_DIR=${TARGET_DIR}/cbbuild/license/sync_gateway

if [[ ! -d ${TARGET_DIR} ]] ; then  mkdir -p ${TARGET_DIR} ; fi
cd         ${TARGET_DIR}

PREFIX=/opt/couchbase-sync-gateway
PREFIXP=./opt/couchbase-sync-gateway

SRC_DIR=godeps/src/github.com/couchbase/sync_gateway
SGW_DIR=${TARGET_DIR}/${SRC_DIR}
BLD_DIR=${SGW_DIR}/build
STAGING=${BLD_DIR}/opt/couchbase-sync-gateway

ACCEL_DIR=${TARGET_DIR}/godeps/src/github.com/couchbaselabs/sync-gateway-accel
ACCEL_PREFIX=/opt/couchbase-sg-accel
ACCEL_PREFIXP=./opt/couchbase-sg-accel
ACCEL_STAGING=${BLD_DIR}/opt/couchbase-sg-accel

if [[ -e ${PREFIX}  ]] ; then sudo rm -rf ${PREFIX}  ; fi
if [[ -e ${STAGING} ]] ; then      rm -rf ${STAGING} ; fi

if [[ -e ${ACCEL_PREFIX}  ]] ; then sudo rm -rf ${ACCEL_PREFIX}  ; fi
if [[ -e ${ACCEL_STAGING}  ]] ; then     rm -rf ${ACCEL_STAGING}  ; fi

                                                #  needed by ~/.rpmmacros
                                                #  called by package-rpm.rb
                                                #
RPM_ROOT_DIR=${BLD_DIR}/build/rpm/couchbase-sync-gateway_${VERSION}-${BLD_NUM}/rpmbuild/
export RPM_ROOT_DIR
env | grep RPM_ROOT_DIR

echo ======== sync sync_gateway ===================
pwd

if [[ ! -d ${STAGING}/bin/      ]] ; then mkdir -p ${STAGING}/bin/      ; fi
if [[ ! -d ${STAGING}/tools/    ]] ; then mkdir -p ${STAGING}/tools/    ; fi
if [[ ! -d ${STAGING}/examples/ ]] ; then mkdir -p ${STAGING}/examples/ ; fi
if [[ ! -d ${STAGING}/service/  ]] ; then mkdir -p ${STAGING}/service/  ; fi

declare -a TEMPLATE_FILES=("${SGW_DIR}/rest/api.go" "${SGW_DIR}/base/version.go")

PRODUCT_NAME=${SG_PRODUCT_NAME}

echo ======== insert ${PRODUCT_NAME} build meta-data ==============
for TF in ${TEMPLATE_FILES[@]}
  do
    cat ${TF} | sed -e "s,@PRODUCT_NAME@,${PRODUCT_NAME},g" \
              | sed -e "s,@PRODUCT_VERSION@,${VERSION}-${BLD_NUM},g" \
              | sed -e "s,@COMMIT_SHA@,${REPO_SHA},g"      > ${TF}.new
    mv  ${TF}      ${TF}.orig
    mv  ${TF}.new  ${TF}
done

echo ======== build ${PRODUCT_NAME} ===============================
DEST_DIR=${SGW_DIR}/bin
rm -rf p ${DEST_DIR}
mkdir -p ${DEST_DIR}

# clean up stale objects switching between GO version
if [[ -d ${SGW_DIR}/pkg ]]
then
    rm -rf ${SGW_DIR}/pkg
fi

# Enable go options for enterprise build
if [[ $EDITION =~ enterprise ]]
then
    GO_EDITION_OPTION='-tags cb_sg_enterprise'
else
    GO_EDITION_OPTION=''
fi

export CGO_ENABLED=1
GOOS=${GOOS} GOARCH=${GOARCH} GOPATH=`pwd`/godeps go install ${GO_EDITION_OPTION} github.com/couchbase/sync_gateway/...
# build gozip
GOOS=${GOOS} GOARCH=${GOARCH} GOPATH=`pwd`/godeps go install github.com/couchbase/ns_server/deps/gocode/src/gozip

if [[ -e ${BIN_DIR}/${EXEC} ]]
  then
    mv -f ${BIN_DIR}/${EXEC} ${DEST_DIR}
    echo ".............................. ${PRODUCT_NAME} Success! Output is: ${DEST_DIR}/${EXEC}"
  else
    echo "############################# ${PRODUCT_NAME} FAIL! no such file: ${BIN_DIR}/${EXEC}"
    exit 55
fi

echo ======== remove build meta-data ==============
for TF in ${TEMPLATE_FILES[@]}
  do
    mv  ${TF}.orig ${TF}
done

# Only build enterprise version of sg_accel
if [[ $EDITION =~ enterprise ]]
then

    PRODUCT_NAME=${ACCEL_PRODUCT_NAME}

    echo ======== insert ${PRODUCT_NAME} build meta-data ==============
    for TF in ${TEMPLATE_FILES[@]}
    do
        cat ${TF} | sed -e "s,@PRODUCT_NAME@,${PRODUCT_NAME},g" \
                  | sed -e "s,@PRODUCT_VERSION@,${VERSION}-${BLD_NUM},g" \
                  | sed -e "s,@COMMIT_SHA@,${REPO_SHA},g"      > ${TF}.new
        mv  ${TF}      ${TF}.orig
        mv  ${TF}.new  ${TF}
    done

    echo ======== build ${PRODUCT_NAME} ===============================

    # clean up stale objects switching between GO version
    if [[ -d ${SGW_DIR}/pkg ]]
    then
        rm -rf ${SGW_DIR}/pkg
    fi


    GOOS=${GOOS} GOARCH=${GOARCH} GOPATH=`pwd`/godeps go install ${GO_EDITION_OPTION} github.com/couchbaselabs/sync-gateway-accel/...

    if [[ -e ${BIN_DIR}/sync-gateway-accel ]]
    then
        mv -f ${BIN_DIR}/sync-gateway-accel ${DEST_DIR}/${ACCEL_EXEC}
        echo ".............................. ${PRODUCT_NAME} Success! Output is: ${DEST_DIR}/${ACCEL_EXEC}"
    else
        echo "############################# ${PRODUCT_NAME} FAIL! no such file: ${BIN_DIR}/${ACCEL_EXEC}"
        exit 56
    fi

    echo ======== remove build meta-data ==============
    for TF in ${TEMPLATE_FILES[@]}
    do
        mv  ${TF}.orig ${TF}
    done

fi # end of  Only build enterprise version of sg_accel

echo ======== full test suite ==================================== `date`
echo ........................ running sync_gateway test.sh
GOOS=${GOOS} GOARCH=${GOARCH} GOPATH=`pwd`/godeps go test ${GO_EDITION_OPTION} github.com/couchbase/sync_gateway/...
test_result=$?
if [ ${test_result} -ne "0" ]
then
    echo "########################### FAIL! sync-gateway Unit test results = ${test_result}"
    exit 66
fi

echo ........................ running sync-gateway-accel test.sh
GOOS=${GOOS} GOARCH=${GOARCH} GOPATH=`pwd`/godeps go test github.com/couchbaselabs/sync-gateway-accel/...
test_result=$?
if [ ${test_result} -ne "0" ]
then
    echo "########################### FAIL! sync-gateway-accel Unit test results = ${test_result}"
    exit 66
fi

echo ======== test with race detector ============================= `date`
echo ........................ running sync_gateway test.sh
GOOS=${GOOS} GOARCH=${GOARCH} GOPATH=`pwd`/godeps go test ${TEST_OPTIONS} ${GO_EDITION_OPTION} github.com/couchbase/sync_gateway/...
test_result_race=$?
if [ ${test_result_race} -ne "0" ]
then
    echo "########################### FAIL! sync_gateway Unit test with -race  = ${test_result_race}"
    exit 66
fi

echo ........................ running sync-gateway-accel test.sh
GOOS=${GOOS} GOARCH=${GOARCH} GOPATH=`pwd`/godeps go test ${TEST_OPTIONS} github.com/couchbaselabs/sync-gateway-accel/...
test_result_race=$?
if [ ${test_result_race} -ne "0" ]
then
    echo "########################### FAIL! sync-gateway-accel Unit test with -race  = ${test_result_race}"
    exit 66
fi

echo ======== build sgcollect_info ===============================
COLLECTINFO_DIR=${SGW_DIR}/tools
COLLECTINFO_DIST=${COLLECTINFO_DIR}/dist/${COLLECTINFO_NAME}

pushd ${COLLECTINFO_DIR}
pyinstaller --onefile ${COLLECTINFO_NAME}
if [[ -e ${COLLECTINFO_DIST} ]]
  then
    echo "..............................SGCOLLECT_INFO Success! Output is: ${COLLECTINFO_DIST}"
  else
    echo "############################# SGCOLLECT-INFO FAIL! no such file: ${COLLECTINFO_DIST}"
    exit 77
fi
popd

echo ======== Prep STAGING for packaging =============================
cp    ${COLLECTINFO_DIST}                  ${STAGING}/tools/
cp    ${BIN_DIR}/gozip                     ${STAGING}/tools/
cp    ${BLD_DIR}/README.txt                ${STAGING}
echo  ${VERSION}-${BLD_NUM}            >   ${STAGING}/VERSION.txt
cp    ${LIC_DIR}/LICENSE_${EDITION}.txt    ${STAGING}/LICENSE.txt
cp -r ${SGW_DIR}/examples                  ${STAGING}
cp    ${SGW_DIR}/service/README.md         ${STAGING}/service
cp -r ${SGW_DIR}/service/script_templates  ${STAGING}/service
cp -rf ${STAGING} ${ACCEL_STAGING}

echo ======== sync_gateway package =============================
cp    ${DEST_DIR}/${EXEC}                ${STAGING}/bin/
cp    ${SGW_DIR}/service/sync_gateway_*  ${STAGING}/service

echo cd ${BLD_DIR}' => ' ./${PKGR} ${PREFIX} ${PREFIXP} ${VERSION}-${BLD_NUM} ${REPO_SHA} ${PLATFORM} ${ARCHP}
cd   ${BLD_DIR}   ;   ./${PKGR} ${PREFIX} ${PREFIXP} ${VERSION}-${BLD_NUM} ${REPO_SHA} ${PLATFORM} ${ARCHP}

echo  ======= prep upload sync_gateway =========
cp ${STAGING}/${PKG_NAME} ${SGW_DIR}/${NEW_PKG_NAME}

if [[ $DISTRO =~ centos  ]] || [[ $DISTRO =~ ubuntu  ]]
  then
    cd ${STAGING}
    rm -f ${PKG_NAME}
    tar cvfz ${TAR_PKG_NAME} *
    cp ${TAR_PKG_NAME} ${SGW_DIR}
fi

# Only package enterprise version of sg_accel
if [[ $EDITION =~ enterprise ]]
then

    echo ======== sg_accel package =============================
    if [[ ${VERSION} == 1.4 ]] || [[ ${VERSION} > 1.4 ]]
    then
        cp -f ${ACCEL_DIR}/examples/basic_sg_accel_config.json ${ACCEL_STAGING}/examples
    fi

    cp    ${DEST_DIR}/${ACCEL_EXEC}      ${ACCEL_STAGING}/bin/
    cp    ${SGW_DIR}/service/sg_accel_*  ${ACCEL_STAGING}/service

    RPM_ROOT_DIR=${BLD_DIR}/build/rpm/couchbase-${ACCEL_NAME}_${VERSION}-${BLD_NUM}/rpmbuild/
    export RPM_ROOT_DIR

    cd ${BLD_DIR}; ./${PKGR} ${ACCEL_PREFIX} ${ACCEL_PREFIXP} ${VERSION}-${BLD_NUM} ${REPO_SHA} ${PLATFORM} ${ARCHP} ${ACCEL_NAME} ${ACCEL_EXEC}

    echo  ======= prep upload sg_accel =========
    cp ${ACCEL_STAGING}/${ACCEL_PKG_NAME} ${SGW_DIR}/${ACCEL_NEW_PKG_NAME}

    if [[ $DISTRO =~ centos  ]] || [[ $DISTRO =~ ubuntu  ]]
    then
        cd ${ACCEL_STAGING}
        rm -f ${ACCEL_PKG_NAME}
        tar cvfz ${ACCEL_TAR_PKG_NAME} *
        cp ${ACCEL_TAR_PKG_NAME} ${SGW_DIR}
    fi

fi # end - Only package enterprise version of sg_accel

cd ${SGW_DIR}
if [[ $DISTRO =~ macosx ]]
then
    md5 ${NEW_PKG_NAME}  > ${NEW_PKG_NAME}.md5
    if [[ $EDITION =~ enterprise ]]
    then
        md5 ${ACCEL_NEW_PKG_NAME}  > ${ACCEL_NEW_PKG_NAME}.md5
    fi
else
    md5sum ${NEW_PKG_NAME}  > ${NEW_PKG_NAME}.md5
    if [[ $EDITION =~ enterprise ]]
    then
        md5sum ${ACCEL_NEW_PKG_NAME}  > ${ACCEL_NEW_PKG_NAME}.md5
    fi
fi


echo ======== D O N E   S L E E P ================= `date`

echo -------........................... uploading internally to ${LATESTBUILDS_SGW}/${NEW_PKG_NAME}

echo ============================================== `date`
