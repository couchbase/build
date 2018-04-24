#!/bin/bash -ex
# http://mobile.jenkins.couchbase.com/view/Couchbase_Lite/job/couchbase-lite-ios-liteserv

BRANCH=${1}
VERSION=${2}
BLD_NUM=${3}
DISTRO=${4}
EDITION=${5}
STORAGE_ENGINE=${6}


if [[ ${DISTRO} =~ "macosx" ]] || [[ ${EDITION} =~ "community" ]]
then
    echo DO NOTHING...for either ${DISTRO} or ${EDITION} version
    exit 0
fi

if [[ ! -d liteserv-ios ]]
then
    git clone https://github.com/couchbaselabs/liteserv-ios.git
fi

cd liteserv-ios

# Get code updates

git clean -dfx
#git checkout ${BRANCH}
git pull
git log -3
git status

git submodule update --init --recursive

# Prepare framework

if [[ ${DISTRO} =~ "tvos" ]]
then
    SCHEME=LiteServ-tvOS
    SDK=appletvsimulator
    SDK_DEVICE=appletvos
    FRAMEWORK_DIR=${WORKSPACE}/liteserv-ios/Frameworks/tvOS
else
    SCHEME=LiteServ-iOS
    SDK=iphonesimulator
    SDK_DEVICE=iphoneos
    FRAMEWORK_DIR=${WORKSPACE}/liteserv-ios/Frameworks/iOS
fi

if [[ -d build ]]; then rm -rf build/*; fi
if [[ -d ${FRAMEWORK_DIR} ]]; then rm -rf ${FRAMEWORK_DIR}/*; fi

pushd ${FRAMEWORK_DIR}
cp /latestbuilds/couchbase-lite-ios/${VERSION}/${DISTRO}/${BLD_NUM}/couchbase-lite-${DISTRO}-enterprise_${VERSION}-${BLD_NUM}.zip .
unzip couchbase-lite-${DISTRO}-enterprise_${VERSION}-${BLD_NUM}.zip
cp Extras/*.a .
cp Extras/*.h .
popd

# Build LiteServ

if [[ ${STORAGE_ENGINE} =~ "SQLCipher" ]]
then
    LITESERV_APP=${SCHEME}-${STORAGE_ENGINE}.app
    LITESERV_APP_DEVICE=${SCHEME}-${STORAGE_ENGINE}-Device.app
    LITESERV_ZIP=${SCHEME}-${STORAGE_ENGINE}.zip
    xcodebuild CURRENT_PROJECT_VERSION=${BLD_NUM} CBL_VERSION_STRING=${VERSION} -scheme ${SCHEME}-${STORAGE_ENGINE} -sdk ${SDK} -configuration Release -derivedDataPath build
    xcodebuild CURRENT_PROJECT_VERSION=${BLD_NUM} CBL_VERSION_STRING=${VERSION} -scheme ${SCHEME}-${STORAGE_ENGINE} -sdk ${SDK_DEVICE} -configuration Release -derivedDataPath build-device -allowProvisioningUpdates
else
    LITESERV_APP=${SCHEME}.app
    LITESERV_APP_DEVICE=${SCHEME}-Device.app
    LITESERV_ZIP=${SCHEME}.zip
    xcodebuild CURRENT_PROJECT_VERSION=${BLD_NUM} CBL_VERSION_STRING=${VERSION} -scheme ${SCHEME} -sdk ${SDK} -configuration Release -derivedDataPath build
    xcodebuild CURRENT_PROJECT_VERSION=${BLD_NUM} CBL_VERSION_STRING=${VERSION} -scheme ${SCHEME} -sdk ${SDK_DEVICE} -configuration Release -derivedDataPath build-device -allowProvisioningUpdates
fi

rm -f *.zip
cp -rf build/Build/Products/Release-${SDK}/${LITESERV_APP} .
cp -rf build-device/Build/Products/Release-${SDK_DEVICE}/${LITESERV_APP} ./${LITESERV_APP_DEVICE}
zip -ry ${LITESERV_ZIP} *.app

echo "Done!"
