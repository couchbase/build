#!/bin/bash -ex

# We assume "repo" has already run, placing the build git as
# ${WORKSPACE}/cbbuild and voltron as ${WORKSPACE}/voltron.
#
# Required job parameters (expected to be in environment):
#
# RELEASE - in the form x.x.x
# EDITION - "enterprise" or "community"
# BLD_NUM - xxxx
#
# (At some point these will instead be read from the manifest.)

# Step 0: Derived values and cleanup.
PRODUCT_VERSION=${RELEASE}-${BLD_NUM}-rel
rm -f *.rpm
rm -rf ~/rpmbuild
rm -rf /opt/couchbase/*

# Step 1: Building prerequisites.
# This step will hopefully be obsoleted by moving all prereqs to cbdeps.
# For now this still uses Voltron's Makefile.

echo
echo =============== 1. Build prerequisites using voltron
echo =============== `date`
echo

# Voltron's Makefile do a "git pull" in grommit, so we have to ensure
# that works. This depends on the remote name in the manifest. All ugly.
cd ${WORKSPACE}/grommit
git checkout -B master membase-priv/master

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
echo =============== `date`
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
make
make install

# Step 3: Create installer, using Voltron.
# Goal is to incorporate the "overlay" steps here into server-rpm.rb,
# so we can completely drop voltron's Makefile.

echo
echo =============== 3. Building installation package
echo =============== `date`
echo

# First we need to create the current.xml manifest. This will eventually be
# passed into the job, but for now we use what repo knows.
cd ${WORKSPACE}
repo manifest -r > current.xml

cd ${WORKSPACE}/voltron
make PRODUCT_VERSION=${PRODUCT_VERSION} LICENSE=LICENSE-enterprise.txt \
     GROMMIT=${WORKSPACE}/grommit BUILD_DIR=${WORKSPACE} \
     TOPDIR=${WORKSPACE}/voltron overlay
cp -R server-overlay-rpm/* /opt/couchbase
PRODUCT_VERSION=${PRODUCT_VERSION} ./server-rpm.rb /opt/couchbase \
   couchbase-server couchbase server 1.0.0
cp ~/rpmbuild/RPMS/x86_64/*.rpm ${WORKSPACE}

echo
echo =============== DONE!
echo =============== `date`
echo
