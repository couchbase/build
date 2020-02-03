#!/bin/bash -ex

# Global define
PRODUCT=${1}
BLD_NUM=${2}
VERSION=${3}
EDITION=${4}

if [[ -z "${WORKSPACE}" ]]; then
    WORKSPACE=`pwd`
fi

mkdir -p ${WORKSPACE}/build_release ${WORKSPACE}/build_debug

case "${OSTYPE}" in
    darwin*)  OS="macosx"
              PKG_CMD='zip -r'
              PKG_TYPE='zip'
              PROP_FILE=${WORKSPACE}/publish.prop
              if [[ ${IOS} == 'true' ]]; then
                  OS="macosx-ios"
                  BUILD_IOS_REL_TARGET='build_ios_release'
                  BUILD_IOS_DEBUG_TARGET='build_ios_debug'
                  PROP_FILE=${WORKSPACE}/publish_ios.prop
                  mkdir -p ${WORKSPACE}/${BUILD_IOS_REL_TARGET} ${WORKSPACE}/${BUILD_IOS_DEBUG_TARGET}
              fi;;
    linux*)   OS="linux"
              PKG_CMD='tar czf'
              PKG_TYPE='tar.gz'
              PROP_FILE=${WORKSPACE}/publish.prop
              OS_NAME=`lsb_release -is`
              if [[ "$OS_NAME" != "CentOS" ]]; then
                  echo "Error: Unsupported Linux distro $OS_NAME"
                  exit 2
              fi

              OS_VERSION=`lsb_release -rs`
              if [[ $OS_VERSION =~ ^6.* ]]; then
                  OS="centos6"
              elif [[ ! $OS_VERSION =~ ^7.* ]]; then
                  echo "Error: Unsupported CentOS version $OS_VERSION"
                  exit 3
              fi;;
    *)        echo "unknown: $OSTYPE"
              exit 1;;
esac

project_dir=couchbase-lite-core
strip_dir=${project_dir}
ios_xcode_proj="couchbase-lite-core/Xcode/LiteCore.xcodeproj"
macosx_lib="libLiteCore.dylib"

if [[ ${EDITION} == 'enterprise' ]]; then
    release_config="Release-EE"
    debug_config="Debug-EE"
else
    release_config="Release"
    debug_config="Debug"
fi

echo VERSION=${VERSION}
# Global define end

if [[ ${IOS} == 'true' ]]; then
    echo "====  Building ios Release binary  ==="
    cd ${WORKSPACE}/${BUILD_IOS_REL_TARGET}
    xcodebuild -project "${WORKSPACE}/${ios_xcode_proj}" -configuration ${release_config} -derivedDataPath ios -scheme "LiteCore framework" -sdk iphoneos BITCODE_GENERATION_MODE=bitcode CODE_SIGNING_ALLOWED=NO
    xcodebuild -project "${WORKSPACE}/${ios_xcode_proj}" -configuration ${release_config} -derivedDataPath ios -scheme "LiteCore framework" -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO
    cp -R ios/Build/Products/${release_config}-iphoneos/LiteCore.framework ${WORKSPACE}/${BUILD_IOS_REL_TARGET}/
    lipo -create ios/Build/Products/${release_config}-iphoneos/LiteCore.framework/LiteCore ios/Build/Products/${release_config}-iphonesimulator/LiteCore.framework/LiteCore -output ${WORKSPACE}/${BUILD_IOS_REL_TARGET}/LiteCore.framework/LiteCore
    cd ${WORKSPACE}
else
    echo "====  Building macosx/linux Release binary  ==="
    cd ${WORKSPACE}/build_release
    cmake -DEDITION=${EDITION} -DCMAKE_INSTALL_PREFIX=`pwd`/install -DCMAKE_BUILD_TYPE=MinSizeRel ..
    make -j8
    if [[ ${OS} == 'linux'  ]] || [[ ${OS} == 'centos6' ]]; then
        ${WORKSPACE}/couchbase-lite-core/build_cmake/scripts/strip.sh ${strip_dir}
    else
        pushd ${project_dir}
        dsymutil ${macosx_lib} -o libLiteCore.dylib.dSYM
        strip -x ${macosx_lib}
        popd
    fi
    make install
    if [[ ${OS} == 'macosx' ]]; then
        # package up the strip symbols
        cp -rp ${project_dir}/libLiteCore.dylib.dSYM  ./install/lib
    else
        # copy C++ stdlib, etc to output
         libstdcpp=`g++ --print-file-name=libstdc++.so`
         libstdcppname=`basename "$libstdcpp"`
         libgcc_s=`gcc --print-file-name=libgcc_s.so`
         libgcc_sname=`basename "$libgcc_s"`

         cp -p "$libstdcpp" "./install/lib/$libstdcppname"
         ln -s "$libstdcppname" "./install/lib/${libstdcppname}.6"
         cp -p "${libgcc_s}" "./install/lib"
    fi
    if [[ -z ${SKIP_TESTS} ]] && [[ ${EDITION} == 'enterprise' ]]; then
        chmod 777 ${WORKSPACE}/couchbase-lite-core/build_cmake/scripts/test_unix.sh
        cd ${WORKSPACE}/build_release/${project_dir} && ${WORKSPACE}/couchbase-lite-core/build_cmake/scripts/test_unix.sh
    fi
    cd ${WORKSPACE}
fi

if [[ ${IOS} == 'true' ]]; then
    echo "====  Building ios Debug binary  ==="
    cd ${WORKSPACE}/${BUILD_IOS_DEBUG_TARGET}
    xcodebuild -project "${WORKSPACE}/${ios_xcode_proj}" -configuration ${debug_config} -derivedDataPath ios -scheme "LiteCore framework" -sdk iphoneos BITCODE_GENERATION_MODE=bitcode CODE_SIGNING_ALLOWED=NO
    xcodebuild -project "${WORKSPACE}/${ios_xcode_proj}" -configuration ${debug_config} -derivedDataPath ios -scheme "LiteCore framework" -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO
    cp -R ios/Build/Products/${debug_config}-iphoneos/LiteCore.framework ${WORKSPACE}/${BUILD_IOS_DEBUG_TARGET}/
    lipo -create ios/Build/Products/${debug_config}-iphoneos/LiteCore.framework/LiteCore ios/Build/Products/${debug_config}-iphonesimulator/LiteCore.framework/LiteCore -output ${WORKSPACE}/${BUILD_IOS_DEBUG_TARGET}/LiteCore.framework/LiteCore
    cd ${WORKSPACE}
else
    echo "====  Building macosx/linux Debug binary  ==="
    cd ${WORKSPACE}/build_debug/
    cmake -DEDITION=${EDITION} -DCMAKE_INSTALL_PREFIX=`pwd`/install -DCMAKE_BUILD_TYPE=Debug ..
    make -j8
    if [[ ${OS} == 'linux' ]] || [[ ${OS} == 'centos6' ]]; then
        ${WORKSPACE}/couchbase-lite-core/build_cmake/scripts/strip.sh ${strip_dir}
    else
        pushd ${project_dir}
        dsymutil ${macosx_lib} -o libLiteCore.dylib.dSYM
        strip -x ${macosx_lib}
        popd
    fi
    make install
    if [[ ${OS} == 'macosx' ]]; then
        # package up the strip symbols
        cp -rp ${project_dir}/libLiteCore.dylib.dSYM  ./install/lib
    else
        # copy C++ stdlib, etc to output
        libstdcpp=`g++ --print-file-name=libstdc++.so`
        libstdcppname=`basename "$libstdcpp"`
        libgcc_s=`gcc --print-file-name=libgcc_s.so`
        libgcc_sname=`basename "$libgcc_s"`

        cp -p "$libstdcpp" "./install/lib/$libstdcppname"
        ln -s "$libstdcppname" "./install/lib/${libstdcppname}.6"
        cp -p "${libgcc_s}" "./install/lib"
    fi
    cd ${WORKSPACE}
fi

# Create zip package
for FLAVOR in release debug;
do
    PACKAGE_NAME=${PRODUCT}-${OS}-${VERSION}-${FLAVOR}.${PKG_TYPE}
    echo
    echo  "=== Creating ${WORKSPACE}/${PACKAGE_NAME} package ==="
    echo

    if [[ "${FLAVOR}" == 'debug' ]]
    then
        if [[ ${IOS} == 'true' ]]; then
            cd ${WORKSPACE}/${BUILD_IOS_DEBUG_TARGET}
            ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} LiteCore.framework
            cd ${WORKSPACE}
            DEBUG_IOS_PKG_NAME=${PACKAGE_NAME}
        else
            DEBUG_PKG_NAME=${PACKAGE_NAME}
            cd ${WORKSPACE}/build_${FLAVOR}/install
            # Create separate symbols pkg
            if [[ ${OS} == 'macosx' ]]; then
                ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} lib/libLiteCore*.dylib
                SYMBOLS_DEBUG_PKG_NAME=${PRODUCT}-${OS}-${VERSION}-${FLAVOR}-'symbols'.${PKG_TYPE}
                ${PKG_CMD} ${WORKSPACE}/${SYMBOLS_DEBUG_PKG_NAME}  lib/libLiteCore.dylib.dSYM
            else # linux
                ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} *
                #if [[ ${EDITION} == 'community' ]]; then
                    SYMBOLS_DEBUG_PKG_NAME=${PRODUCT}-${OS}-${VERSION}-${FLAVOR}-'symbols'.${PKG_TYPE}
                    cd ${WORKSPACE}/build_${FLAVOR}/${strip_dir}
                    ${PKG_CMD} ${WORKSPACE}/${SYMBOLS_DEBUG_PKG_NAME} libLiteCore*.sym
                #fi
            fi
            cd ${WORKSPACE}
        fi
    else
        if [[ ${IOS} == 'true' ]]; then
            cd ${WORKSPACE}/${BUILD_IOS_REL_TARGET}
            ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} LiteCore.framework
            cd ${WORKSPACE}
            RELEASE_IOS_PKG_NAME=${PACKAGE_NAME}
        else
            RELEASE_PKG_NAME=${PACKAGE_NAME}
            cd ${WORKSPACE}/build_${FLAVOR}/install
            # Create separate symbols pkg
            if [[ ${OS} == 'macosx' ]]; then
                ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} lib/libLiteCore*.dylib
                SYMBOLS_RELEASE_PKG_NAME=${PRODUCT}-${OS}-${VERSION}-${FLAVOR}-'symbols'.${PKG_TYPE}
                ${PKG_CMD} ${WORKSPACE}/${SYMBOLS_RELEASE_PKG_NAME}  lib/libLiteCore.dylib.dSYM
            else # linux
                ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} *
                #if [[ ${EDITION} == 'community' ]]; then
                    SYMBOLS_RELEASE_PKG_NAME=${PRODUCT}-${OS}-${VERSION}-${FLAVOR}-'symbols'.${PKG_TYPE}
                    cd ${WORKSPACE}/build_${FLAVOR}/${strip_dir}
                    ${PKG_CMD} ${WORKSPACE}/${SYMBOLS_RELEASE_PKG_NAME} libLiteCore*.sym
                #fi
            fi
            cd ${WORKSPACE}
        fi
    fi
done

# Create Nexus publishing prop file
cd ${WORKSPACE}
echo "PRODUCT=${PRODUCT}"  >> ${PROP_FILE}
echo "BLD_NUM=${BLD_NUM}"  >> ${PROP_FILE}
echo "VERSION=${VERSION}" >> ${PROP_FILE}
echo "PKG_TYPE=${PKG_TYPE}" >> ${PROP_FILE}
if [[ ${IOS} == 'true' ]]; then
    echo "DEBUG_IOS_PKG_NAME=${DEBUG_IOS_PKG_NAME}" >> ${PROP_FILE}
    echo "RELEASE_IOS_PKG_NAME=${RELEASE_IOS_PKG_NAME}" >> ${PROP_FILE}
else
    echo "DEBUG_PKG_NAME=${DEBUG_PKG_NAME}" >> ${PROP_FILE}
    echo "RELEASE_PKG_NAME=${RELEASE_PKG_NAME}" >> ${PROP_FILE}
    echo "SYMBOLS_DEBUG_PKG_NAME=${SYMBOLS_DEBUG_PKG_NAME}" >> ${PROP_FILE}
    echo "SYMBOLS_RELEASE_PKG_NAME=${SYMBOLS_RELEASE_PKG_NAME}" >> ${PROP_FILE}
fi

echo
echo  "=== Created ${WORKSPACE}/${PROP_FILE} ==="
echo

cat ${PROP_FILE}
