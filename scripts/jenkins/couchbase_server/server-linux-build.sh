#!/bin/bash -ex

# We assume "repo" has already run, placing the build git as
# ${WORKSPACE}/cbbuild and voltron as ${WORKSPACE}/voltron.
#
# Required job parameters (expected to be in environment):
# DISTRO  - Distribution name (eg., "ubuntu12.04", "debian7", "centos6", "macos")
#     This will be used to determine the pacakging format (.deb, .rpm, or .zip).
# VERSION - in the form x.x.x
# EDITION - "enterprise" or "community"
# BLD_NUM - xxxx
#
# (At some point these will instead be read from the manifest.)
#

usage() {
    echo "Usage: $0 [ ubuntu12.04 | debian7 | centos6 | ... ] <VERSION> <EDITION> <BLD_NUM>"
    exit 5
}

if [ "$#" -ne 4 ]
then
    usage
fi

DISTRO=$1
case "$DISTRO" in
    centos*)
        PKG=rpm
        FLAVOR=redhat
        ;;
    *suse*)
        PKG=rpm
        FLAVOR=suse
        ;;
    debian*|ubuntu*)
        PKG=deb
        ;;
    macos)
        PKG=mac
        ;;
    nopkg)
        echo "Skipping packaging step"
        ;;
    *)
        usage
        ;;
esac

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
PRODUCT_VERSION=${VERSION}-${BLD_NUM}-rel
rm -f *.rpm *.deb *.zip
rm -rf ~/rpmbuild
rm -rf ${WORKSPACE}/voltron/build/deb
rm -rf /opt/couchbase/*
find goproj godeps -name \*.a -print0 | xargs -0 rm -f

# Step 1: Build Couchbase Server itself, using CMake.

echo
echo =============== 1. Build Couchbase Server using CMake
echo
cd ${WORKSPACE}
mkdir -p build
cd build
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
      -D CB_DOWNLOAD_DEPS=1 \
      -D SNAPPY_OPTION=Disable \
      ..
make -j8 install || (
    echo; echo; echo -------------
    echo make -j8 failed - re-running with no -j8 to hopefully get better debug output
    echo -------------; echo; echo
    make
    exit 2
)

# couchdbx-app on MacOS depends on this:
rm -f ${WORKSPACE}/install && ln -s /opt/couchbase ${WORKSPACE}/install


# Step 2: Create installer, using Voltron.  Goal is to incorporate the
# "build-filter" and "overlay" steps here into server-rpm/deb.rb, so
# we can completely drop voltron's Makefile.

echo
echo =============== 2. Building installation package
echo

# We still need to create this for voltron's "overlay" step.
cd ${WORKSPACE}
repo manifest -r > current.xml

if [ "${DISTRO}" = "nopkg" ]
then
    echo "Skipping packaging as requested; all done!"
    exit 0
fi

# Tweak install directory in Voltron-magic fashion
cd ${WORKSPACE}/voltron
make PRODUCT_VERSION=${PRODUCT_VERSION} LICENSE=LICENSE-enterprise.txt \
     BUILD_DIR=${WORKSPACE} \
     TOPDIR=${WORKSPACE}/voltron build-filter overlay
if [ -d "server-overlay-${PKG}" ]
then
    # common to all distros
    cp -R server-overlay-${PKG}/common/* /opt/couchbase

    if [ "${PKG}" = "rpm" ]
    then
        cp -R server-overlay-${PKG}/${FLAVOR}/* /opt/couchbase
        cp server-rpm.${FLAVOR}.spec.tmpl server-rpm.spec.tmpl
        cp moxi-rpm.${FLAVOR}.spec.tmpl moxi-rpm.spec.tmpl
    fi
fi

# Execute platform-specific packaging step
PRODUCT_VERSION=${PRODUCT_VERSION} LD_LIBRARY_PATH=/opt/couchbase/lib \
   ./server-${PKG}.rb /opt/couchbase couchbase-server couchbase server 1.0.0
if [ "${PKG}" = "mac" ]
then
    cd ${WORKSPACE}/couchdbx-app
    LICENSE=LICENSE-${EDITION}.txt make license
    # Xcode leaves stale precompiled headers and expects us to clean them up
    find /var/folders -type d -name SharedPrecompiledHeaders | xargs rm -rf
    make couchbase-server-zip
    cd ${WORKSPACE}
fi

# Move final installation package to top of workspace, and set up
# trigger.properties for downstream jobs
case "$PKG" in
    rpm)
        ARCHITECTURE=x86_64
        INSTALLER_FILENAME=couchbase-server-${EDITION}-${VERSION}-${BLD_NUM}-${DISTRO}.${ARCHITECTURE}.rpm
        DBG_FILENAME=couchbase-server-${EDITION}-debug-${VERSION}-${BLD_NUM}-${DISTRO}.${ARCHITECTURE}.rpm
        cp ~/rpmbuild/RPMS/x86_64/couchbase-server-[1-9]*.rpm ${WORKSPACE}/${INSTALLER_FILENAME}
	if [ "${FLAVOR}" = "redhat" ]
	then
            cp ~/rpmbuild/RPMS/x86_64/couchbase-server-debug-*.rpm ${WORKSPACE}/${DBG_FILENAME}
	elif [ "${FLAVOR}" = "suse" ]
	then
            cp ~/rpmbuild/RPMS/x86_64/couchbase-server-debuginfo-*.rpm ${WORKSPACE}/${DBG_FILENAME}
	else
	    echo "Error: Unknown FLAVOR '${FLAVOR}'"
	    exit 6
	fi
        ;;
    deb)
        ARCHITECTURE=amd64
        INSTALLER_FILENAME=couchbase-server-${EDITION}_${VERSION}-${BLD_NUM}-${DISTRO}_${ARCHITECTURE}.deb
        DBG_FILENAME=couchbase-server-${EDITION}-dbg_${VERSION}-${BLD_NUM}-${DISTRO}_${ARCHITECTURE}.deb
        cp build/deb/couchbase-server_*.deb ${WORKSPACE}/${INSTALLER_FILENAME}
        cp build/deb/couchbase-server-dbg_*.deb ${WORKSPACE}/${DBG_FILENAME}
        ;;
    mac)
        ARCHITECTURE=x86_64
        INSTALLER_FILENAME=couchbase-server-${EDITION}_${VERSION}-${BLD_NUM}-${DISTRO}_${ARCHITECTURE}.zip
        cp couchdbx-app/build/Release/*.zip ${WORKSPACE}/${INSTALLER_FILENAME}
        ;;
esac

echo Creating trigger.properties...
cd ${WORKSPACE}
cat <<EOF > trigger.properties
ARCHITECTURE=${ARCHITECTURE}
PLATFORM=${DISTRO}
INSTALLER_FILENAME=${INSTALLER_FILENAME}
BUILD_WORKSPACE=${WORKSPACE}
EOF

echo
echo =============== DONE!
echo
