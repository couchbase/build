#!/bin/bash
#          
#          run by jenkins jobs: 'mobile_functional_tests_android_master'
#                               'mobile_functional_tests_android_100'
#          
#          called with paramters:
#             
#             RELEASE           0.0.0, 1.0.0
#             SYNCGATE_VERSION  ( hard-coded to run on centos-x64 )
#             ANDROID_VERSION
#             EDITION
#             
##############
#            
#   see:     http://redsymbol.net/articles/bash-exit-traps/
#
function kill_child_processes
    {
    echo ============================================ killing child processes
    jobs -l | awk '{print "kill    "$2" || true"}' | bash
    echo ============================================ try again after 15 sec.
    sleep  15
  # for I in {a..o} ; do echo -n '=' ; sleep 1 ; done ; echo
    jobs -l | awk '{print "kill -9 "$2" || true"}' | bash
    }
function finish
    {
    EXIT_STATUS=$?
    if [[ ${EXIT_STATUS} > 0 ]]
        then
        echo ============================================
        echo ============  SIGNAL CAUGHT:  ${EXIT_STATUS}
        echo ============================================
    fi
    kill_child_processes
    echo ============================================ make file handles closed
  # for I in {a..o} ; do echo -n '=' ; sleep 1 ; done ; echo
    sleep 15
    echo ============================================  `date`
    }
trap finish EXIT
##############

source ~jenkins/.bash_profile
set -e

DEBUG=1

function usage
    {
    echo -e "\nuse:  ${0}   release  android.version   syncgateway.version  edtion\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
RELEASE=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
SYNCGATE_VERSION=${2}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
ANDROID_VERSION=${3}

if [[ ! ${4} ]] ; then usage ; exit 66 ; fi
EDITION=${4}


PLATFORM=linux-amd64
if [[ ${EDITION} =~ 'community' ]]
  then
    SGW_PKG=couchbase-sync-gateway_${SYNCGATE_VERSION}_x86_64-${EDITION}.rpm
    AND_PKG=couchbase-lite-${ANDROID_VERSION}-android-community.zip
else
    SGW_PKG=couchbase-sync-gateway_${SYNCGATE_VERSION}_x86_64.rpm
    AND_PKG=couchbase-lite-${ANDROID_VERSION}-android.zip
fi

SGW_PKGSTORE=s3://packages.couchbase.com/builds/mobile/sync_gateway/${RELEASE}/${SYNCGATE_VERSION}
AND_PKGSTORE=s3://packages.couchbase.com/builds/mobile/android/${RELEASE}/${ANDROID_VERSION}
export SGW_PKGSTORE
export AND_PKGSTORE

GET_CMD="s3cmd get"


AUT_DIR=${WORKSPACE}/app-under-test
if [[ -e ${AUT_DIR} ]] ; then rm -rf ${AUT_DIR} ; fi
mkdir -p ${AUT_DIR}/android_liteserv
mkdir -p ${AUT_DIR}/sync_gateway

LITESERV_DIR=${AUT_DIR}/android_liteserv
SYNCGATE_DIR=${AUT_DIR}/sync_gateway

DOWNLOAD=${AUT_DIR}/download

export LITESERV_PATH=${LITESERV_DIR}
export LITESERV_PORT=8080

                  # specific to host:
export AND_TARG=27
export EMULATOR=cblite

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ install liteserv
rm   -rf ${DOWNLOAD}
mkdir -p ${DOWNLOAD}
pushd    ${DOWNLOAD} 2>&1 > /dev/null

${GET_CMD} ${AND_PKGSTORE}/${AND_PKG}

cd ${LITESERV_DIR}
if [[ ! -e ${DOWNLOAD}/${AND_PKG} ]] ; then echo "Android LiteServ download failed, cannot find ${DOWNLOAD}/${AND_PKG}" ; exit 99 ; fi
unzip   -q ${DOWNLOAD}/${AND_PKG}

popd                 2>&1 > /dev/null

echo ============================================ install sync_gateway
rm   -rf ${SYNCGATE_DIR}
mkdir -p ${SYNCGATE_DIR}
pushd    ${SYNCGATE_DIR} 2>&1 > /dev/null

${GET_CMD} ${SGW_PKGSTORE}/${SGW_PKG}
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
echo ============================================ killing any child processes
kill_child_processes

echo ===================================================================================== starting Android LiteServ
cd ${LITESERV_PATH}
echo ".......................................creating avd"
echo no | android create avd -n ${EMULATOR} -t ${AND_TARG} --abi armeabi-v7a --force

echo ".......................................starting emulator"
# remove Android emulator temporary directory
rm -rf /tmp/android-${USER}

adb shell setprop debug.assert ${DEBUG}
emulator64-arm -avd ${EMULATOR} -no-window -verbose -no-audio -no-skin -netspeed full -netdelay none &
echo ".......................................waiting for emulator"
echo ""
sleep 10
adb wait-for-device
sleep 30

OUT=`adb shell getprop init.svc.bootanim`
while [[ ${OUT:0:7}  != 'stopped' ]]
  do
    OUT=`adb shell getprop init.svc.bootanim`
    echo 'Waiting for emulator to fully boot...'
    sleep 10
done

adb shell am start -a android.intent.action.MAIN -n com.couchbase.liteservandroid/com.couchbase.liteservandroid.MainActivity --ei listen_port ${LITESERV_PORT}
adb forward  tcp:${LITESERV_PORT}  tcp:${LITESERV_PORT}


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
