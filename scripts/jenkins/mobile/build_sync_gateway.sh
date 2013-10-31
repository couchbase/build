#!/bin/bash
#          
#          run by jenkins job 'build_sync_gateway'
#          
#          with paramters:  branch_name  release number
#          
#                 e.g.:     master         0.0
#                 e.g.:     stable         1.0
#          
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

env | grep -iv password | grep -iv passwd | sort -u
echo ==============================================

ZIP_FILE=sync_gateway_${REVISION}.zip
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
echo .................... running compile.sh
                                ./compile.sh

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
