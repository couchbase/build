#!/bin/bash
#          
#          run by jenkins jobs: 'mobile_functional_tests_android_master'
#                               'mobile_functional_tests_android_100'
#          
#          called with paramters:
#             
#             LITESERV_VERSION
#             SYNCGATE_VERSION  ( hard-coded to run on centos-x64 )
#                                 now of the form n.n-mmmm
#             EDITION
#             
source ~jenkins/.bash_profile
set -e

function usage
    {
    echo -e "\nuse:  ${0}   liteserv.version   syncgateway.version  edtion\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
SYNCGATE_VERSION=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
LITESERV_VERSION=${2}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
EDITION=${3}


PLATFORM=linux-amd64
if [[ ${EDITION} =~ 'community' ]]
  then
    SGW_PKG=couchbase-sync-gateway_${SYNCGATE_VERSION}_x86_64-${EDITION}.rpm
    LIT_PKG=cblite_ios_${LITESERV_VERSION}-${EDITION}.zip
else
    SGW_PKG=couchbase-sync-gateway_${SYNCGATE_VERSION}_x86_64.rpm
    LIT_PKG=cblite_ios_${LITESERV_VERSION}.zip
fi

SGW_PKGSTORE=s3://packages.couchbase.com/builds/mobile/ios/${VERSION}/${SYNCGATE_VERSION}
LIT_PKGSTORE=s3://packages.couchbase.com/builds/mobile/ios/${VERSION}/${LITESERV_VERSION}


AUT_DIR=${WORKSPACE}/app-under-test
if [[ -e ${AUT_DIR} ]] ; then rm -rf ${AUT_DIR} ; fi
mkdir -p ${AUT_DIR}/liteserv
mkdir -p ${AUT_DIR}/sync_gateway

LITESERV_DIR=${AUT_DIR}/liteserv
SYNCGATE_DIR=${AUT_DIR}/sync_gateway

#export SYNCGATE_PATH=${SYNCGATE_DIR}/sync_gateway

DOWNLOAD=${AUT_DIR}/download

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ install liteserv
rm   -rf ${DOWNLOAD}
mkdir -p ${DOWNLOAD}
pushd    ${DOWNLOAD} 2>&1 > /dev/null

wget --no-verbose ${LIT_PKGSTORE}/${LIT_PKG}

cd ${LITESERV_DIR}
if [[ ! -e ${DOWNLOAD}/${LIT_PKG} ]] ; then echo "LiteServ download failed, cannot find ${DOWNLOAD}/${LIT_PKG}" ; exit 99 ; fi
unzip   -q ${DOWNLOAD}/${LIT_PKG}
                                                         # want all of the zip file contents
export LITESERV_PATH=${LITESERV_DIR}/LiteServ.app/Contents/MacOS/LiteServ

popd                 2>&1 > /dev/null

echo ============================================ install sync_gateway
rm   -rf ${SYNCGATE_DIR}
mkdir -p ${SYNCGATE_DIR}
pushd    ${SYNCGATE_DIR} 2>&1 > /dev/null

wget --no-verbose ${SGW_PKGSTORE}/${SGW_PKG}
STATUS=$?
if [[ ${STATUS} > 0 ]] ; then echo "FAILED to download ${SGW_PKG}" ; exit ${STATUS} ; fi

sudo rpm --erase   couchbase-sync-gateway || true
sudo rpm --install ${SGW_PKG}

popd                 2>&1 > /dev/null

cd ${WORKSPACE}
echo ============================================ sync cblite-tests
if [[ ! -d cblite-tests ]] ; then git clone https://github.com/couchbaselabs/cblite-tests.git ; fi
cd cblite-tests
git pull
git show --stat

echo ============================================ npm install
mkdir -p tmp/single
npm install  2>&1  >  ${WORKSPACE}/npm_install.log
cat                   ${WORKSPACE}/npm_install.log
echo ============================================ killing any hanging LiteServ
killall LiteServ || true

# echo ===================================================================================== starting ${LITESERV_PATH}
# ${LITESERV_PATH} | tee  ${WORKSPACE}/liteserv.log & 
#
# echo ===================================================================================== starting ./node_modules/.bin/tap
# export TAP_TIMEOUT=500
# ./node_modules/.bin/tap ./tests       1> ${WORKSPACE}/results.log  2> ${WORKSPACE}/gateway.log

echo ============================================ npm test
export TAP_TIMEOUT=20000
npm test 2>&1 | tee  ${WORKSPACE}/npm_test_results.log

echo ============================================ killing any hanging LiteServ
killall LiteServ || true

FAILS=`cat ${WORKSPACE}/npm_test_results.log | grep 'npm ERR!' | wc -l`
if [[ $((FAILS)) > 0 ]] 
  then
    echo ============================================ exit: ${FAILS}
    exit ${FAILS}
  else
    echo ============================================ DONE
    exit ${FAILS}
fi
