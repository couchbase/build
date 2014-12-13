#!/bin/bash -e

# Expects to be run from the latestbuilds directory.

RELEASE=3.0.2
BUILD=1603

ROOT=s3://packages.couchbase.com/releases/$RELEASE
STAGING=.staging

RELEASE_DIR=/home/buildbot/releases/$RELEASE
mkdir -p $RELEASE_DIR

upload()
{
    build=$1
    target=$2

    if [ ! -e /tmp/$build.md5 ]
    then
        echo Creating fresh md5sum file for $build...
        md5sum $build | cut -c1-32 > /tmp/$build.md5
    fi

    echo Uploading $build...
    s3cmd sync -P $build $ROOT/$target$STAGING
    s3cmd sync -P /tmp/$build.md5 $ROOT/$target.md5$STAGING

    echo Copying $build to releases...
    cp $build $RELEASE_DIR/$target
    cp /tmp/$build.md5 $RELEASE_DIR/$target.md5
}

if [ ! -e couchbase-server_$RELEASE-src.tgz ]
then
    echo 'Create the source tarball with create_tarball.sh!'
    exit 1
fi
upload couchbase-server_$RELEASE-src.tgz couchbase-server_$RELEASE-src.tgz

upload couchbase-server-community_centos6_x86_64_$RELEASE-$BUILD-rel.rpm \
  couchbase-server-community-$RELEASE-centos6.x86_64.rpm
upload couchbase-server-enterprise_centos6_x86_64_$RELEASE-$BUILD-rel.rpm \
  couchbase-server-enterprise-$RELEASE-centos6.x86_64.rpm

upload couchbase-server-community_x86_64_$RELEASE-$BUILD-rel.rpm \
  couchbase-server-community-$RELEASE-centos5.x86_64.rpm
upload couchbase-server-enterprise_x86_64_$RELEASE-$BUILD-rel.rpm \
  couchbase-server-enterprise-$RELEASE-centos5.x86_64.rpm

upload couchbase-server-community_debian7_x86_64_$RELEASE-$BUILD-rel.deb \
  couchbase-server-community_$RELEASE-debian7_amd64.deb
upload couchbase-server-enterprise_debian7_x86_64_$RELEASE-$BUILD-rel.deb \
  couchbase-server-enterprise_$RELEASE-debian7_amd64.deb

upload couchbase-server-community_ubuntu_1204_x86_64_$RELEASE-$BUILD-rel.deb \
  couchbase-server-community_$RELEASE-ubuntu12.04_amd64.deb
upload couchbase-server-enterprise_ubuntu_1204_x86_64_$RELEASE-$BUILD-rel.deb \
  couchbase-server-enterprise_$RELEASE-ubuntu12.04_amd64.deb

upload couchbase-server-community_x86_64_$RELEASE-$BUILD-rel.deb \
  couchbase-server-community_$RELEASE-ubuntu10.04_amd64.deb
upload couchbase-server-enterprise_x86_64_$RELEASE-$BUILD-rel.deb \
  couchbase-server-enterprise_$RELEASE-ubuntu10.04_amd64.deb

upload couchbase-server-community_x86_64_$RELEASE-$BUILD-rel.zip \
  couchbase-server-community_$RELEASE-macos_x86_64.zip
upload couchbase-server-enterprise_x86_64_$RELEASE-$BUILD-rel.zip \
  couchbase-server-enterprise_$RELEASE-macos_x86_64.zip

upload couchbase_server-community-windows-amd64-$RELEASE-$BUILD.exe \
  couchbase-server-community_$RELEASE-windows_amd64.exe
upload couchbase_server-enterprise-windows-amd64-$RELEASE-$BUILD.exe \
  couchbase-server-enterprise_$RELEASE-windows_amd64.exe

upload couchbase_server-community-windows-x86-$RELEASE-$BUILD.exe \
  couchbase-server-community_$RELEASE-windows_x86.exe
upload couchbase_server-enterprise-windows-x86-$RELEASE-$BUILD.exe \
  couchbase-server-enterprise_$RELEASE-windows_x86.exe

