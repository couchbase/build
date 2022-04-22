#!/bin/bash -ex

# Global define
PRODUCT=${1}
VERSION=${2}
BLD_NUM=${3}
ARCH=${4}
EDITION=${5}

PKG_TYPE='zip'
PKG_CMD='zip -r'

ANDROID_NDK_VERSION=android-ndk-r15c
ANDROID_NDK_ROOT=~/android-ndk-r15c
CMAKE_VERSION="3.10.2.4988404"
SDK_HOME=~/jenkins/tools/android-sdk
SDK_MGR="${SDK_HOME}/cmdline-tools/latest/bin/sdkmanager"
CMAKE_PATH="${SDK_HOME}/cmake/${CMAKE_VERSION}/bin"
export PATH=${CMAKE_PATH}:${PATH}

if [ ! -d ${CMAKE_PATH} ]; then
    yes | ${SDK_MGR} --licenses > /dev/null 2>&1
    ${SDK_MGR} --install "cmake;${CMAKE_VERSION}"
fi

if [ ! -d ${ANDROID_NDK_ROOT} ]; then
    curl -LO https://dl.google.com/android/repository/${ANDROID_NDK_VERSION}-linux-x86_64.zip
    unzip -q -o ${ANDROID_NDK_VERSION}-linux-x86_64.zip -d ~/.
    rm -f ${ANDROID_NDK_VERSION}-linux-x86_64.zip
fi

case "${OSTYPE}" in
    linux*) if [[ ${ARCH} == 'x86' ]]; then
                OS="android-x86"
                BUILD_REL_TARGET='build_x86_release'
                BUILD_DEBUG_TARGET='build_x86_debug'
                ARCH_VERSION='19'
                PROP_FILE=${WORKSPACE}/publish_x86.prop
                STRIP=`dirname $(find $ANDROID_NDK_ROOT/toolchains -name strip | grep x86-)`
            fi
            if [[ ${ARCH} == 'armeabi-v7a' ]]; then
                OS="android-armeabi-v7a"
                BUILD_REL_TARGET='build_armeabi-v7a_release'
                BUILD_DEBUG_TARGET='build_armeabi-v7a_debug'
                ARCH_VERSION='19'
                PROP_FILE=${WORKSPACE}/publish_armeabi-v7a.prop
                STRIP=`dirname $(find $ANDROID_NDK_ROOT/toolchains -name strip | grep arm)`
            fi
            if [[ ${ARCH} == 'arm64-v8a' ]]; then
                OS="android-arm64-v8a"
                BUILD_REL_TARGET='build_arm64-v8a_release'
                BUILD_DEBUG_TARGET='build_arm64-v8a_debug'
                ARCH_VERSION='21'
                PROP_FILE=${WORKSPACE}/publish_arm64-v8a.prop
                STRIP=`dirname $(find $ANDROID_NDK_ROOT/toolchains -name strip | grep aarch64)`
            fi
            if [[ ${ARCH} == 'x86_64' ]]; then
                OS="android-x86_64"
                BUILD_REL_TARGET='build_x86_64_release'
                BUILD_DEBUG_TARGET='build_x86_64_debug'
                ARCH_VERSION='21'
                PROP_FILE=${WORKSPACE}/publish_x86_64.prop
                STRIP=`dirname $(find $ANDROID_NDK_ROOT/toolchains -name strip | grep x86_64-)`
            fi;;
        *)  echo "unknown: $OSTYPE"
            exit 1;;
esac
mkdir -p ${WORKSPACE}/${BUILD_REL_TARGET} ${WORKSPACE}/${BUILD_DEBUG_TARGET}
# Global define end

project_dir=couchbase-lite-core
strip_dir=${project_dir}

echo "====  Building Android $ARCH_VERSION Release binary  ==="
cd ${WORKSPACE}/${BUILD_REL_TARGET}
cmake -DEDITION=${EDITION} -DCMAKE_INSTALL_PREFIX=`pwd`/install -DCMAKE_SYSTEM_NAME=Android -DCMAKE_ANDROID_NDK=${ANDROID_NDK_ROOT} \
      -DCMAKE_ANDROID_ARCH_ABI=$ARCH -DCMAKE_ANDROID_NDK_TOOLCHAIN_VERSION=clang \
      -DCMAKE_SYSTEM_VERSION=$ARCH_VERSION -DCMAKE_ANDROID_STL_TYPE=c++_static -DCMAKE_BUILD_TYPE=MinSizeRel  ..
make -j4
${WORKSPACE}/couchbase-lite-core/build_cmake/scripts/strip.sh ${strip_dir} ${STRIP}/
make install
cd ${WORKSPACE}

echo "====  Building Android $ARCH_VERSION Debug binary  ==="
cd ${WORKSPACE}/${BUILD_DEBUG_TARGET}
cmake -DEDITION=${EDITION}  -DCMAKE_INSTALL_PREFIX=`pwd`/install -DCMAKE_SYSTEM_NAME=Android -DCMAKE_ANDROID_NDK=${ANDROID_NDK_ROOT} \
      -DCMAKE_ANDROID_ARCH_ABI=$ARCH -DCMAKE_ANDROID_NDK_TOOLCHAIN_VERSION=clang \
      -DCMAKE_SYSTEM_VERSION=$ARCH_VERSION -DCMAKE_ANDROID_STL_TYPE=c++_static -DCMAKE_BUILD_TYPE=Debug  ..
make -j4
${WORKSPACE}/couchbase-lite-core/build_cmake/scripts/strip.sh ${strip_dir} ${STRIP}/
make install
cd ${WORKSPACE}

# Create zip package
for FLAVOR in release debug;
do
    PACKAGE_NAME=${PRODUCT}-${OS}-${VERSION}-${FLAVOR}.${PKG_TYPE}
    echo
    echo  "=== Creating ${WORKSPACE}/${PACKAGE_NAME} package ==="
    echo

    if [[ ${FLAVOR} == 'debug' ]]
    then
        cd ${WORKSPACE}/${BUILD_DEBUG_TARGET}/install
        ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} *
        DEBUG_PKG_NAME=${PACKAGE_NAME}
        cd ${WORKSPACE}
    else
        cd ${WORKSPACE}/${BUILD_REL_TARGET}/install
        ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} *
        RELEASE_PKG_NAME=${PACKAGE_NAME}
        cd ${WORKSPACE}
    fi
done

# Create Nexus publishing prop file
cd ${WORKSPACE}
echo "PRODUCT=${PRODUCT}"  >> ${PROP_FILE}
echo "BLD_NUM=${BLD_NUM}"  >> ${PROP_FILE}
echo "VERSION=${VERSION}" >> ${PROP_FILE}
echo "PKG_TYPE=${PKG_TYPE}" >> ${PROP_FILE}
echo "DEBUG_PKG_NAME=${DEBUG_PKG_NAME}" >> ${PROP_FILE}
echo "RELEASE_PKG_NAME=${RELEASE_PKG_NAME}" >> ${PROP_FILE}

echo
echo  "=== Created ${WORKSPACE}/${PROP_FILE} ==="
echo

cat ${PROP_FILE}
