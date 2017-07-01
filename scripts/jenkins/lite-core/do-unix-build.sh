#!/bin/bash -ex

# Global define
PRODUCT=${1}
VERSION=${2}
BLD_NUM=${3}

case "${OSTYPE}" in
    darwin*)  OS="macosx"
              PKG_CMD='zip -r'
              PKG_TYPE='zip';;
    linux*)   OS="linux"
              PKG_CMD='tar czf'
              PKG_TYPE='tar.gz';;
    *)        echo "unknown: $OSTYPE"
              exit 1;;
esac

PROP_FILE=${WORKSPACE}/publish.prop
# Global define end

mkdir -p ${WORKSPACE}/build_release ${WORKSPACE}/build_debug

echo "====  Building Release binary  ==="

cd ${WORKSPACE}/build_release/
cmake -DCMAKE_INSTALL_PREFIX=`pwd`/install -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLITECORE_BUILD_SQLITE=1  ..
make -j8
make install
chmod 777 ${WORKSPACE}/couchbase-lite-core/build_cmake/scripts/test_unix.sh
cd ${WORKSPACE}/build_release/couchbase-lite-core && ../../couchbase-lite-core/build_cmake/scripts/test_unix.sh
cd ${WORKSPACE}

if [[ "${OS}" == 'macosx' ]]
then
    echo "====  Building Debug binary  ==="

    cd ${WORKSPACE}/build_debug/
    cmake -DCMAKE_INSTALL_PREFIX=`pwd`/install -DCMAKE_BUILD_TYPE=Debug -DLITECORE_BUILD_SQLITE=1 ..
    make -j8
    make install
    cd ${WORKSPACE}/build_debug/couchbase-lite-core && ../../couchbase-lite-core/build_cmake/scripts/test_unix.sh
    cd ${WORKSPACE}
fi

VERSION=$(git -C "${WORKSPACE}/couchbase-lite-core" rev-parse HEAD)

# Create zip package
for FLAVOR in release debug;
do
    if [[ "${FLAVOR}" == 'debug' && "${OS}" == 'linux' ]]
    then
        continue
    fi
    PACKAGE_NAME=${PRODUCT}-${OS}-${VERSION}-${FLAVOR}.${PKG_TYPE}
    echo
    echo  "=== Creating ${WORKSPACE}/${PACKAGE_NAME} package ==="
    echo
    cd ${WORKSPACE}/build_${FLAVOR}/install
    ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} *
    if [[ "${FLAVOR}" == 'debug' ]]
    then
        DEBUG_PKG_NAME=${PACKAGE_NAME}
    else
        RELEASE_PKG_NAME=${PACKAGE_NAME}
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
