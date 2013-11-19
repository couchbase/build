#!/bin/bash
#          
#          run by jenkins jobs: 'mobile_functional_tests_android_master'
#                               'mobile_functional_tests_android_stable'
#          
#          with job paramters:
#             
#             LITESERV_VERSION
#             SYNCGATE_VERSION
#             
#          and called with paramters:                release_number
#          
#             mobile_functional_tests_android_master:     0.0
#             mobile_functional_tests_android_stable:     1.0
#             
source ~jenkins/.bash_profile
set -e

function usage
    {
    echo -e "\nuse:  ${0}   release_number\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
VERSION=${1}


PLATFORM=linux-amd64

AUT_DIR=${WORKSPACE}/app-under-test
if [[ -e ${AUT_DIR} ]] ; then rm -rf ${AUT_DIR} ; fi
mkdir -p ${AUT_DIR}/liteserv
mkdir -p ${AUT_DIR}/sync_gateway

LITESERV_VER=${VERSION}-${LITESERV_VERSION}
LITESERV_DIR=${AUT_DIR}/liteserv

SYNCGATE_VER=${VERSION}-${SYNCGATE_VERSION}
SYNCGATE_DIR=${AUT_DIR}/sync_gateway

DOWNLOAD=${AUT_DIR}/download

echo ============================================
env | grep -iv password | grep -iv passwd | sort

echo ============================================ install liteserv
rm   -rf ${DOWNLOAD}
mkdir -p ${DOWNLOAD}
pushd    ${DOWNLOAD} 2>&1 > /dev/null

wget --no-verbose http://cbfs.hq.couchbase.com:8484/builds/cblite_ios_${LITESERV_VER}.zip

cd ${LITESERV_DIR}
if [[ ! -e ${DOWNLOAD}/cblite_ios_${LITESERV_VER}.zip ]] ; then echo "LiteServ download failed, cannot find ${DOWNLOAD}/cblite_ios_${LITESERV_VER}.zip" ; exit 99 ; fi
unzip   -q ${DOWNLOAD}/cblite_ios_${LITESERV_VER}.zip
                                                         # want all of the zip file contents
export LITESERV_PATH=${LITESERV_DIR}/LiteServ

popd                 2>&1 > /dev/null

echo ============================================ install sync_gateway
rm   -rf ${DOWNLOAD}
mkdir -p ${DOWNLOAD}
pushd    ${DOWNLOAD} 2>&1 > /dev/null

wget --no-verbose http://cbfs.hq.couchbase.com:8484/builds/sync_gateway_${SYNCGATE_VER}.zip
unzip -q sync_gateway_${SYNCGATE_VER}.zip
                                                         # want to choose from the zip file contents
export SYNCGATE_PATH=${SYNCGATE_DIR}/sync_gateway
cp ${PLATFORM}/sync_gateway ${SYNCGATE_PATH}

popd                 2>&1 > /dev/null
echo ============================================ run tests
cd ${WORKSPACE}
if [[ ! -d cblite-tests ]] ; then git clone https://github.com/couchbaselabs/cblite-tests.git ; fi
cd cblite-tests
git pull
git show --stat

mkdir -p tmp/single
npm install  2>&1  >    ${WORKSPACE}/npm_install.log
echo ===================================================================================== killing any hanging com.couchbase.liteservandroid apps
adb shell am force-stop com.couchbase.liteservandroid
# echo ===================================================================================== starting ${LITESERV_PATH}
# ${LITESERV_PATH}  | tee ${WORKSPACE}/liteserv.log & 

# echo ===================================================================================== starting ./node_modules/.bin/tap
# export TAP_TIMEOUT=500
# ./node_modules/.bin/tap ./tests       1> ${WORKSPACE}/results.log  2> ${WORKSPACE}/gateway.log

echo ===================================================================================== starting npm
npm test > ${WORKSPACE}/results.log  2> ${WORKSPACE}/gateway.log

echo ===================================================================================== killing any hanging LiteServ
adb shell am force-stop com.couchbase.liteservandroid || true


echo ===================================================================================== DONE
