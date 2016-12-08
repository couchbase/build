#!/bin/bash -ex

# We assume "repo" has already run, placing the build git as
# ${WORKSPACE}/cbbuild and voltron as ${WORKSPACE}/voltron.
#
# Required job parameters (expected to be in environment):
# DISTRO  - Distribution name (eg., "ubuntu12.04", "debian7", "centos6", "macos")
#     This will be used to determine the pacakging format (.deb, .rpm, or .zip).
# VERSION - in the form x.x.x
# BLD_NUM - xxxx
#
# (At some point these will instead be read from the manifest.)
#

usage() {
    echo "Usage: $0 [ ubuntu12.04 | debian7 | centos6 | ... ] <VERSION> <BLD_NUM>"
    exit 5
}

if [ "$#" -ne 3 ]
then
    usage
fi

DISTRO=$1
case "$DISTRO" in
    centos6)
        PKG=rpm
        FLAVOR=redhat6
        ;;
    centos7)
        PKG=rpm
        FLAVOR=redhat7
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
export BLD_NUM=$3

# Compute WORKSPACE, if not in environment
if [ -z "${WORKSPACE}" ]
then
    WORKSPACE="$( cd "$(dirname "$0")"/../../../.. ; pwd -P )"
fi

# Step 0: Derived values and cleanup. (Some of these are RPM- or
# DEB-specific, but will safely do nothing on other systems.)
export PRODUCT_VERSION=${VERSION}-${BLD_NUM}
rm -f *.rpm *.deb *.zip
rm -rf ~/rpmbuild ~/build
rm -rf ${WORKSPACE}/voltron/build/deb
rm -rf /opt/moxi/*

# This should be created in the Docker container, but for now at least...
sudo mkdir -p /opt/moxi
sudo chown $(id -u):$(id -g) /opt/moxi

# Step 1: Build Moxi itself, using CMake.

echo
echo =============== 1. Build Moxi using CMake
echo
cd ${WORKSPACE}
mkdir -p build
cd build
cmake -D CMAKE_INSTALL_PREFIX=/opt/moxi \
      -D CMAKE_PREFIX_PATH=/opt/moxi \
      -D CMAKE_BUILD_TYPE=RelWithDebInfo \
      -D PRODUCT_VERSION=${PRODUCT_VERSION} \
      ${EXTRA_CMAKE_OPTIONS} \
      ..
make -j8 install || (
    echo; echo; echo -------------
    echo make -j8 failed - re-running with no -j8 to hopefully get better debug output
    echo -------------; echo; echo
    make
    exit 2
)

if [ "${DISTRO}" = "nopkg" ]
then
    echo "Skipping packaging as requested; all done!"
    exit 0
fi

# Step 2: Create installer, using Voltron.  Goal is to incorporate the
# "build-filter" and "overlay" steps here, so we can completely drop
# voltron's Makefile and the ruby scripts.

echo
echo =============== 2. Building installation package
echo

# Pre-clean all unnecessary files
cd /opt/moxi/bin
rm -rf curl tools

# Remove unneeded libs (couldn't figure out how to do this using
# objdump etc - libevent naming, at least, tripped it up - so
# I just prune a few I know I don't need)
cd /opt/moxi/lib
rm -f libJSON_checker* libbreakpad_wrapper* libdirutils* libevent_extra* libevent_pthreads*

# Tweak install directory in Voltron-magic fashion
cd ${WORKSPACE}/voltron
cp /opt/moxi/bin/moxi /opt/moxi/bin/moxi.actual
cp -aR moxi-overlay/* /opt/moxi
cp LICENSE-moxi.txt /opt/moxi/LICENSE.txt
mkdir /opt/moxi/logs
if [ -d "moxi-overlay-${PKG}" ]
then
    if [ "${PKG}" = "rpm" ]
    then
        overlay="moxi-overlay-${PKG}/${FLAVOR}"
    else
        overlay="moxi-overlay-${PKG}"
    fi
    cp -aR ${overlay}/* /opt/moxi
fi

cxxlib_needed="debian7|suse11|ubuntu12"
if [[ "$DISTRO" =~ $cxxlib_needed ]]
then
    libstdcpp=`g++ --print-file-name=libstdc++.so`
    libstdcppname=`basename "$libstdcpp"`
    cp -p "$libstdcpp" "/opt/moxi/lib/$libstdcppname"
    ln -s "$libstdcppname" "/opt/moxi/lib/${libstdcppname}.6"
fi

PRODUCT=moxi-server
export LD_LIBRARY_PATH=/opt/moxi/lib

# Execute platform-specific packaging steps
case "${PKG}" in
  rpm)
    # RPMs require a "source tarball", so whip one up
    mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/BUILD ~/rpmbuild/RPMS
    tar --directory /opt -czf "${HOME}/rpmbuild/SOURCES/${PRODUCT}_${VERSION}.tar.gz" moxi

    sed -e "s,@@VERSION@@,${VERSION},g" moxi-rpm.${FLAVOR}.spec.tmpl |
      sed -e "s,@@RELEASE@@,${BLD_NUM},g" > moxi-rpm.spec

    rpmbuild -bb moxi-rpm.spec
    ;;
  deb)
    STAGE_DIR="${HOME}/build/deb/${PRODUCT}_${VERSION}-${BLD_NUM}"
    mkdir -p ${STAGE_DIR}/opt ${STAGE_DIR}/etc ${STAGE_DIR}/debian
    cp -aR /opt/moxi ${STAGE_DIR}/opt
    cp -a moxi-deb/* ${STAGE_DIR}/debian
    cd ${STAGE_DIR}
    dch -b -v ${VERSION} "Released debian package for version ${VERSION}"
    dpkg-buildpackage -b
    ;;
esac

# Move final installation package to top of workspace, and set up
# trigger.properties for downstream jobs
case "$PKG" in
    rpm)
        ARCHITECTURE=x86_64
        INSTALLER_FILENAME=${PRODUCT}-${VERSION}-${BLD_NUM}-${DISTRO}.${ARCHITECTURE}.rpm
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
        if [ -n "$DEBUG" ]
        then
          cp ${DBG_PREFIX}-${DEBUG}-*.rpm \
             ${WORKSPACE}/${PRODUCT}-${DEBUG}-${VERSION}-${BLD_NUM}-${DISTRO}.${ARCHITECTURE}.rpm
        fi
        ;;
    deb)
        ARCHITECTURE=amd64
        INSTALLER_FILENAME=${PRODUCT}_${VERSION}-${BLD_NUM}-${DISTRO}_${ARCHITECTURE}.deb
        DBG_FILENAME=${PRODUCT}-dbg_${VERSION}-${BLD_NUM}-${DISTRO}_${ARCHITECTURE}.deb
        cp ~/build/deb/${PRODUCT}_*.deb ${WORKSPACE}/${INSTALLER_FILENAME}
        if ls ~/build/deb/${PRODUCT}-dbg_*.deb > /dev/null 2>&1;
        then
          cp ~/build/deb/${PRODUCT}-dbg_*.deb ${WORKSPACE}/${DBG_FILENAME}
        fi
        ;;
esac

# Back to the top
cd ${WORKSPACE}

echo Creating trigger.properties...
cat <<EOF > trigger.properties
ARCHITECTURE=${ARCHITECTURE}
PLATFORM=${DISTRO}
INSTALLER_FILENAME=${INSTALLER_FILENAME}
BUILD_WORKSPACE=${WORKSPACE}
EOF

echo
echo =============== DONE!
echo
