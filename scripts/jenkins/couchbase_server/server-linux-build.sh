#!/bin/bash -ex

# We assume "repo" has already run, placing the build git as
# ${WORKSPACE}/cbbuild and voltron as ${WORKSPACE}/voltron.
#
# Required job parameters (expected to be in environment):
#
# VERSION - in the form x.x.x
# EDITION - "enterprise" or "community"
# BLD_NUM - xxxx
#
# (At some point these will instead be read from the manifest.)
#
# Optional job parameters (expected to be in environment):
#
# RUN_SIMPLE_TEST - if non-empty, will run "make simple-test" after build
#
# Required script command-line parameter:
#
#   Distribution name (eg., "ubuntu12.04", "debian7", "centos6", "macos")
#
# This will be used to determine the pacakging format (.deb, .rpm, or .zip).

DISTRO=$1
case "$DISTRO" in
    centos*)
        PKG=rpm
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
        echo "Usage: $0 [ ubuntu12.04 | debian7 | centos6 | ... ]"
        exit 2
        ;;
esac

# Step 0: Derived values and cleanup. (Some of these are RPM- or
# DEB-specific, but will safely do nothing on other systems.)
PRODUCT_VERSION=${VERSION}-${BLD_NUM}-rel
rm -f *.rpm *.deb *.zip
rm -rf ~/rpmbuild
rm -rf ${WORKSPACE}/voltron/build/deb
rm -rf /opt/couchbase/*
find goproj godeps -name \*.a -print0 | xargs -0 rm -f

# Step 1: Building prerequisites.
# This step will hopefully be obsoleted by moving all prereqs to cbdeps.
# For now this still uses Voltron's Makefile.

echo
echo =============== 1. Build prerequisites using voltron
echo

# Voltron's Makefile do a "git pull" in grommit, so we have to ensure
# that works. Create a "master" branch tracking the upstream repository.
cd ${WORKSPACE}/grommit
git checkout -B master
git config branch.master.remote membase-priv
git config branch.master.merge refs/heads/master

cd ${WORKSPACE}/voltron
make GROMMIT=${WORKSPACE}/grommit BUILD_DIR=${WORKSPACE} \
     TOPDIR=${WORKSPACE}/voltron dep-couchbase.tar.gz

# I don't know why this doesn't cause problems for the normal build, but
# ICU sticks stuff in /opt/couchbase/sbin that the RPM template file
# doesn't want.
rm -rf /opt/couchbase/sbin

# Voltron's Makefile also assumes /opt/couchbase/lib/python is a directory.
# I don't actually know where this is supposed to come from. It also appears
# to be deleted by something in the dep-couchbase.tar.gz build, so I need to
# re-create it here before building the pystuff.
mkdir -p /opt/couchbase/lib/python
make GROMMIT=${WORKSPACE}/grommit BUILD_DIR=${WORKSPACE} \
    TOPDIR=${WORKSPACE}/voltron pysqlite2 pysnappy2

# Step 2: Build Couchbase Server itself, using CMake.

echo
echo =============== 2. Build Couchbase Server using CMake
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
      -D CMAKE_BUILD_TYPE=Release \
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

# Step 3: simple-test.

echo
echo =============== 3. Run simple-test
echo
if [ -z "${RUN_SIMPLE_TEST}" ]
then
    echo Skipping simple-test
else
    cd ${WORKSPACE}/testrunner
    export COUCHBASE_REPL_TYPE=upr
    failed=0
    make simple-test || failed=1
    sudo killall -9 beam.smp epmd memcached python >/dev/null || true
    if [ $failed = 1 ]
    then
        echo Tests failed - aborting run
        exit 3
    fi
    zip cluster_run_log cluster_run.log
fi

# Step 4: Create installer, using Voltron.  Goal is to incorporate the
# "build-filter" and "overlay" steps here into server-rpm/deb.rb, so
# we can completely drop voltron's Makefile.

echo
echo =============== 4. Building installation package
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
     GROMMIT=${WORKSPACE}/grommit BUILD_DIR=${WORKSPACE} \
     TOPDIR=${WORKSPACE}/voltron build-filter overlay
if [ -d "server-overlay-${PKG}" ]
then
    cp -R server-overlay-${PKG}/* /opt/couchbase
fi

# Execute platform-specific packaging step
PRODUCT_VERSION=${PRODUCT_VERSION} ./server-${PKG}.rb /opt/couchbase \
   couchbase-server couchbase server 1.0.0
if [ "${PKG}" = "mac" ]
then
    cd ${WORKSPACE}/couchdbx-app
    LICENSE=LICENSE-${EDITION}.txt make license
    make couchbase-server-zip
    cd ${WORKSPACE}
fi

# Move final installation package to top of workspace, and set up
# trigger.properties for downstream jobs
case "$PKG" in
    rpm)
        ARCHITECTURE=x86_64
        INSTALLER_FILENAME=couchbase-server-${EDITION}-${VERSION}-${BLD_NUM}-${DISTRO}.${ARCHITECTURE}.rpm
        cp ~/rpmbuild/RPMS/x86_64/*.rpm ${WORKSPACE}/${INSTALLER_FILENAME}
        ;;
    deb)
        ARCHITECTURE=amd64
        INSTALLER_FILENAME=couchbase-server-${EDITION}_${VERSION}-${BLD_NUM}-${DISTRO}_${ARCHITECTURE}.deb
        cp build/deb/*.deb ${WORKSPACE}/${INSTALLER_FILENAME}
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
EOF

echo
echo =============== DONE!
echo
