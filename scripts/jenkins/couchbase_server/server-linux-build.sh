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
    echo "Usage: $0 [ ubuntu18.04 | debian9 | centos7 | ... ] <VERSION> <EDITION> <BLD_NUM>"
    exit 5
}

# Utility function to compress an uncompressed .deb. Skips operation
# if environment variable SKIP_COMPRESS is set to any non-empty value;
# useful for debugging.
compress_deb() {
    DEB=$1
    if [ ! -z "${SKIP_COMPRESS}" ]
    then
        return
    fi

    # This file always contains these three exact files: debian-binary,
    # control.tar[.gz], and data.tar or data.tar.xz, in that order. We want to
    # replace data.tar with data.tar.xz when necessary.
    rm -f debian-binary control.tar* data.tar data.tar.xz
    ar x ${DEB}
    if [ -e data.tar ]
    then
        pixz data.tar data.tar.xz
        rm ${DEB}
        ar rc ${DEB} debian-binary control.tar* data.tar.xz
    fi
    rm -f debian-binary control.tar* data.tar data.tar.xz
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

DISTRO=$1
case "$DISTRO" in
    amzn2)
        PKG=rpm
        FLAVOR=amzn2
        ;;
    centos7)
        PKG=rpm
        FLAVOR=redhat7
        ;;
    centos8|rhel8)
        PKG=rpm
        FLAVOR=redhat8
        ;;
    *suse12)
        PKG=rpm
        FLAVOR=suse12
        ;;
    *suse15)
        PKG=rpm
        FLAVOR=suse15
        GPG_KEY='Couchbase Release Key (RPM)'
        ;;
    debian*|ubuntu*)
        PKG=deb
        FLAVOR=systemd
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
export PRODUCT_VERSION=${VERSION}-${BLD_NUM}
rm -f *.rpm *.deb *.zip trigger*.properties
rm -rf ~/rpmbuild
rm -rf ${WORKSPACE}/voltron/build
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
      ..
make -j8 install

# couchdbx-app on MacOS depends on this:
rm -f ${WORKSPACE}/install && ln -s /opt/couchbase ${WORKSPACE}/install

if [ "${DISTRO}" = "nopkg" ]
then
    echo "Skipping packaging as requested; all done!"
    exit 0
fi

# Step 2: Create installer, using Voltron.  Goal is to incorporate the
# "build-filter" and "overlay" steps here or into server-rpm/deb.rb, so
# we can completely drop voltron's Makefile.

echo
echo =============== 2. Building installation package
echo

# Pre-clean all unnecessary files
cd ${WORKSPACE}
ruby voltron/cleanup.rb /opt/couchbase

# We still need to create this for voltron's "overlay" step, if it's not
# already there.
if [ ! -e "manifest.xml" ]
then
    repo manifest -r > manifest.xml
fi

# Tweak install directory in Voltron-magic fashion
cd ${WORKSPACE}/voltron
make PRODUCT_VERSION=${PRODUCT_VERSION} BUILD_ENTERPRISE=${BUILD_ENTERPRISE} \
     BUILD_DIR=${WORKSPACE} DISTRO=${DISTRO} \
     TOPDIR=${WORKSPACE}/voltron build-filter overlay
if [ -d "server-overlay-${PKG}" ]
then
    if [ "${PKG}" = "rpm" ]
    then
        cp -R server-overlay-${PKG}/${FLAVOR}/* /opt/couchbase
    fi
fi

# Copy libstdc++ and libgcc_s into distribution package. Necessary
# on all Linux platforms since we build our own GCC now.
if [ "${PKG}" != "mac" ]
then
    libstdcpp=`g++ --print-file-name=libstdc++.so`
    libstdcppname=`basename "$libstdcpp"`
    cp -p "$libstdcpp" "/opt/couchbase/lib/$libstdcppname"
    ln -s "$libstdcppname" "/opt/couchbase/lib/${libstdcppname}.6"

    libgcc_s=`gcc --print-file-name=libgcc_s.so`
    libgcc_sname=`basename "$libgcc_s"`
    if [ "${DISTRO}" = 'amzn2' -o "${DISTRO}" = 'rhel8' -o "${DISTRO}" = 'suse15' ]
    then
        cp -p "${libgcc_s}" "/opt/couchbase/lib"
    else
        cp -p "${libgcc_s}.1" "/opt/couchbase/lib"
    fi
fi

# We briefly had a time when we produced multiple "enterprise" artifacts.
# This is no longer used, but leaving the code structure in place in case
# we want it again in future.
if [ "${EDITION}" = "enterprise" ]
then
    EDITIONS=enterprise
else
    EDITIONS=community
fi

for EDITION in ${EDITIONS}
do
    # The "product name" (passed to voltron) is couchbase-server for Enterprise
    # and couchbase-server-community for Community, to keep them distinguished
    # in deb/rpm repositories.
    if [ "${EDITION}" = "enterprise" ]
    then
        PRODUCT=couchbase-server
    else
        PRODUCT=couchbase-server-${EDITION}
    fi

    # Execute platform-specific packaging step
    cd ${WORKSPACE}/voltron
    ./server-${PKG}.rb /opt/couchbase ${PRODUCT} couchbase ${FLAVOR}

    if [ "${PKG}" = "mac" ]
    then
        # Xcode leaves stale precompiled headers and expects us to clean them up
        find /var/folders -type d -name SharedPrecompiledHeaders | xargs rm -rf

        cd ${WORKSPACE}/couchdbx-app
        BUILD_ENTERPRISE=${BUILD_ENTERPRISE} make couchbase-server-zip
        cd ${WORKSPACE}
    fi

    # Move final installation package to top of workspace, and set up
    # trigger.properties for downstream jobs
    case "$PKG" in
        rpm)
            ARCHITECTURE=x86_64
            INSTALLER_FILENAME=couchbase-server-${EDITION}-${VERSION}-${BLD_NUM}-${DISTRO}.${ARCHITECTURE}.rpm
            cp ~/rpmbuild/RPMS/x86_64/${PRODUCT}-[0-9]*.rpm ${WORKSPACE}/${INSTALLER_FILENAME}

            # Debuginfo package. Older versions of RHEL name the it "*-debug-*.rpm";
            # newer ones and SuSE use "-debuginfo-*.rpm".
            # Scan for both and move to correct final name.
            DBG_PREFIX="${HOME}/rpmbuild/RPMS/x86_64/${PRODUCT}"
            DEBUG=""
            if ls ${DBG_PREFIX}-debug-*.rpm > /dev/null 2>&1;
            then
              DEBUG=debug
            elif ls ${DBG_PREFIX}-debuginfo-*.rpm > /dev/null 2>&1;
            then
              DEBUG=debuginfo
            else
              echo "Warning: No ${PRODUCT}-{debug,debuginfo}-*.rpm package found; skipping copy."
            fi

            DBG_FILENAME=couchbase-server-${EDITION}-${DEBUG}-${VERSION}-${BLD_NUM}-${DISTRO}.${ARCHITECTURE}.rpm
            if [ -n "$DEBUG" ]
            then
              cp ${DBG_PREFIX}-${DEBUG}-*.rpm ${WORKSPACE}/${DBG_FILENAME}
            fi

            if [ -n "$GPG_KEY" ]
            then
                rpmsign --addsign --key-id "$GPG_KEY" ${WORKSPACE}/${INSTALLER_FILENAME}
                rpmsign --addsign --key-id "$GPG_KEY" ${WORKSPACE}/${DBG_FILENAME}
            fi

            ;;
        deb)
            ARCHITECTURE=amd64
            INSTALLER_FILENAME=couchbase-server-${EDITION}_${VERSION}-${BLD_NUM}-${DISTRO}_${ARCHITECTURE}.deb
            DBG_FILENAME=couchbase-server-${EDITION}-dbg_${VERSION}-${BLD_NUM}-${DISTRO}_${ARCHITECTURE}.deb
            cp build/deb/${PRODUCT}_*.deb ${WORKSPACE}/${INSTALLER_FILENAME}
            cp build/deb/${PRODUCT}-dbg_*.deb ${WORKSPACE}/${DBG_FILENAME}
            compress_deb ${WORKSPACE}/${INSTALLER_FILENAME}
            compress_deb ${WORKSPACE}/${DBG_FILENAME}
            ;;
        mac)
            ARCHITECTURE=x86_64
            INSTALLER_FILENAME=couchbase-server-${EDITION}_${VERSION}-${BLD_NUM}-${DISTRO}_${ARCHITECTURE}-unsigned.zip
            cp couchdbx-app/build/Release/*.zip ${WORKSPACE}/${INSTALLER_FILENAME}
            ;;
    esac

    # Back to the top
    cd ${WORKSPACE}

    TRIGGER_FILE=trigger.properties
    echo Creating ${TRIGGER_FILE}...
    cat <<EOF > ${TRIGGER_FILE}
ARCHITECTURE=${ARCHITECTURE}
PLATFORM=${DISTRO}
INSTALLER_FILENAME=${INSTALLER_FILENAME}
EDITION=${EDITION}
EOF

# End of PRODUCTS loop
done

# Support for Oracle Enterprise Linux. If we're building Centos 6 or 7, make
# an exact copy with an oel6/oel7 filename.
case "$DISTRO" in
    centos6|centos7)
        for rpm in *.rpm
        do
            cp ${rpm} ${rpm//centos/oel}
        done
        ;;
esac

echo
echo =============== DONE!
echo
