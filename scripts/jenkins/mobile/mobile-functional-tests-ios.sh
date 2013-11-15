#!/bin/bash
PLATFORM=darwin-amd64
export PATH=/usr/local/bin:$PATH

AUT_DIR=${WORKSPACE}/app-under-test
if [[ -e ${AUT_DIR} ]] ; then rm -rf ${AUT_DIR} ; fi
mkdir -p ${AUT_DIR}/liteserv
mkdir -p ${AUT_DIR}/sync_gateway

LITESERV_VER=1.0-${LITESERV_VERSION}
LITESERV_DIR=${AUT_DIR}/liteserv

SYNCGATE_VER=1.0-${SYNCGATE_VERSION}
SYNCGATE_DIR=${AUT_DIR}/sync_gateway

DOWNLOAD=${AUT_DIR}/download
env | sort
#--------------------------------------------  install liteserv
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
#--------------------------------------------  install sync_gateway
rm   -rf ${DOWNLOAD}
mkdir -p ${DOWNLOAD}
pushd    ${DOWNLOAD} 2>&1 > /dev/null

wget --no-verbose http://cbfs.hq.couchbase.com:8484/builds/sync_gateway_${SYNCGATE_VER}.zip
unzip -q sync_gateway_${SYNCGATE_VER}.zip
                                                         # want to choose from the zip file contents
export SYNCGATE_PATH=${SYNCGATE_DIR}/sync_gateway
cp ${PLATFORM}/sync_gateway ${SYNCGATE_PATH}

popd                 2>&1 > /dev/null
#--------------------------------------------  run tests

if [[ ! -d cblite-tests ]] ; then git clone https://github.com/couchbaselabs/cblite-tests.git ; fi
cd cblite-tests
git pull
git show --stat

mkdir -p tmp/single
npm install  2>&1  >    ${WORKSPACE}/npm_install.log
echo ===================================================================================== killing any hanging LiteServ
killall LiteServ || true
# echo ===================================================================================== starting ${LITESERV_PATH}
# ${LITESERV_PATH}  | tee ${WORKSPACE}/liteserv.log & 

# echo ===================================================================================== starting ./node_modules/.bin/tap
# export TAP_TIMEOUT=500
# ./node_modules/.bin/tap ./tests       1> ${WORKSPACE}/results.log  2> ${WORKSPACE}/gateway.log

echo ===================================================================================== starting npm
npm test > ${WORKSPACE}/results.log  2> ${WORKSPACE}/gateway.log

echo ===================================================================================== killing any hanging LiteServ
killall LiteServ || true


echo ===================================================================================== DONE
