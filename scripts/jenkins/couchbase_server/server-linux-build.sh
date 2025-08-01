#!/bin/bash -ex

# We assume "repo" has already run, placing the build git as
# ${WORKSPACE}/cbbuild.
#
# Required job parameters (expected to be in environment):
# DISTRO  - Distribution name (eg., "linux", "macos")
#     This will be used to determine the pacakging format (.deb, .rpm, or .zip).
# VERSION - in the form x.x.x
# EDITION - "enterprise" or "community"
# BLD_NUM - xxxx
#

usage() {
    echo "Usage: $0 [ linux | macos | nopkg ] <VERSION> <EDITION> <BLD_NUM>"
    exit 5
}

if [ "$#" -ne 4 ]
then
    usage
fi

if [ ! -w /opt/couchbase ]
then
    set +x
    echo
    echo
    echo /opt/couchbase must exist and be writable to the current user
    echo
    echo
    exit 5
fi

ARCH=$(uname -m)

DISTRO=$1
# Only check the "root" of DISTRO (anything up to a hyphen) for the platform
# information. That allows to have add-on parameters, such as "linux-asan"
# for sanitized builds.
case "${DISTRO/-*/}" in
    linux)
        PKG=linux
        ;;
    macos)
        PKG=mac
        ;;
    nopkg)
        PKG=nopkg
        echo "Skipping packaging step"
        ;;
    *)
        usage
        ;;
esac

# Disable this KV speed optimization - for now at least it takes too much
# RAM on our build agents
EXTRA_CMAKE_OPTIONS="${EXTRA_CMAKE_OPTIONS} -DCB_UNITY_BUILD=OFF"

# Handle special build arguments for ASAN build
case "$DISTRO" in
    *-asan)
        EXTRA_CMAKE_OPTIONS="${EXTRA_CMAKE_OPTIONS} -DCB_ADDRESSSANITIZER=1 -DCB_UNDEFINEDSANITIZER=1"
        ;;
esac

# Add code-coverage intrumentation if CODE_COVERAGE=true.
if [ "${CODE_COVERAGE}" = "true" ]
then
    CODE_COVERAGE_OPTIONS="-DCMAKE_CXX_FLAGS=-fprofile-arcs -ftest-coverage -pthread -std=c++11 -O0"
fi

export VERSION=$2
export EDITION=$3
export BLD_NUM=$4

# Compute WORKSPACE, if not in environment
if [ -z "${WORKSPACE}" ]
then
    WORKSPACE="$( cd "$(dirname "$0")"/../../../.. ; pwd -P )"
fi

# Step 0: Derived values and cleanup. (Some of these are RPM- or
# DEB-specific, but will safely do nothing on other systems.)
export PRODUCT_VERSION=${VERSION}-${BLD_NUM}
rm -f *.rpm *.deb *.zip trigger*.properties
# We need to ensure we remove the contents rather than the directory so we
# don't error out if ~/rpmbuild is a bind mount
[ -d ~/rpmbuild ] && rm -rf ~/rpmbuild/*
rm -rf /opt/couchbase/*
find goproj godeps -name \*.a -print0 | xargs -0 rm -f

# Step 1: Build Couchbase Server itself, using CMake.

echo
echo =============== 1. Build Couchbase Server using CMake
echo
cd ${WORKSPACE}
export SERVER_BUILD_DIR="$(pwd)/server_build"
mkdir -p "${SERVER_BUILD_DIR}"
cd "${SERVER_BUILD_DIR}"
if [ "${EDITION}" = "enterprise" ]
then
    BUILD_ENTERPRISE=TRUE
else
    BUILD_ENTERPRISE=FALSE
fi
cmake -D CMAKE_INSTALL_PREFIX=/opt/couchbase \
      -D CMAKE_PREFIX_PATH=/opt/couchbase \
      -D CMAKE_BUILD_TYPE=RelWithDebInfo \
      -D PRODUCT_VERSION=${PRODUCT_VERSION} \
      -D BUILD_ENTERPRISE=${BUILD_ENTERPRISE} \
      -D CB_DEVELOPER_BUILD=True \
      -D CB_DOWNLOAD_JAVA=True \
      -D CB_DOWNLOAD_DEPS=1 \
      -D CB_INVOKE_MAVEN=True \
      ${EXTRA_CMAKE_OPTIONS} \
      "${CODE_COVERAGE_OPTIONS}" \
      ..

# Default to 4 build threads, but allow override
NUM_THREADS=${CB_BUILD_PARALLELISM-4}

# Add BUILD_TARGET variable so that make target can be overwritten if necessary.
BUILD_TARGET="${BUILD_TARGET:-install}"

make -j${NUM_THREADS} ${BUILD_TARGET}

# couchdbx-app on MacOS depends on this:
rm -f ${WORKSPACE}/install && ln -s /opt/couchbase ${WORKSPACE}/install

if [ "${PKG}" = "nopkg" ]
then
    echo "Skipping packaging as requested; all done!"
    exit 0
fi

# Make Standalone Tools packages - only for shipping EE builds.
case "${DISTRO}-${ARCH}-${EDITION}" in
    linux-x86_64-enterprise|linux-aarch64-enterprise|macos-x86_64-enterprise|macos-arm64-enterprise)
        make -j2 standalone-packages
        cp "${SERVER_BUILD_DIR}"/couchbase-server-*-${PRODUCT_VERSION}* ${WORKSPACE}
        ;;
esac

# Make metrics-metadata deliverable - should be identical on all platforms
# and arches, so just do it once.
case "${DISTRO}-${ARCH}-${EDITION}" in
    linux-x86_64-enterprise)
        echo "Creating metrics_metadata deliverable"
        METRICS_DIR="${SERVER_BUILD_DIR}/metrics"
        mkdir -p "${METRICS_DIR}"
        pushd /opt/couchbase/etc/couchbase
        for json in */metrics_metadata.json; do
            component=$(dirname ${json})
            cp ${json} "${METRICS_DIR}/${component}_metrics_metadata.json"
        done
        popd
        pushd "${METRICS_DIR}"
        tar czf "${WORKSPACE}/metrics_metadata_${PRODUCT_VERSION}.tar.gz" *
        popd
        ;;
esac

# Step 2: Create installer.

echo
echo =============== 2. Building installation package
echo

# Execute platform-specific packaging step
cd ${SERVER_BUILD_DIR}
make -j2 package-${PKG}

if [ "${PKG}" = "mac" ]
then
    # Xcode leaves stale precompiled headers and expects us to clean them up
    find /var/folders -type d -name SharedPrecompiledHeaders | xargs rm -rf

    # QQQ maybe ADD_SUBDIRECTORY(couchdbx-app), move the package-mac
    # target there, and have it do this?
    cd ${WORKSPACE}/couchdbx-app
    BUILD_ENTERPRISE=${BUILD_ENTERPRISE} make couchbase-server-zip
    cd ${WORKSPACE}

    # Move final installation package to top of workspace
    # QQQ Soon we'll need to devise a different package naming
    # convention here, to account for separate x86_64 / M1 packages
    INSTALLER_FILENAME=couchbase-server-${EDITION}_${VERSION}-${BLD_NUM}-${DISTRO}_${ARCH}-unsigned.zip
    cp couchdbx-app/build/Release/*.zip ${WORKSPACE}/${INSTALLER_FILENAME}
fi

# Back to the top
cd ${WORKSPACE}

# ALL DONE!!

# Set up trigger.properties for downstream jobs.
TRIGGER_FILE=trigger.properties
echo Creating ${TRIGGER_FILE}...
cat <<EOF > ${TRIGGER_FILE}
ARCHITECTURE=${ARCH}
PLATFORM=${DISTRO}
EDITION=${EDITION}
EOF

echo
echo =============== DONE!
echo
