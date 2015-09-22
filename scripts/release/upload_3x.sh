#!/bin/bash -e

# Expects to be run from the latestbuilds directory.

RELEASE=3.1.0
MP=MP1
BUILD=1797
STAGING=
COMMUNITY=private

# Don't modify anything below this line


# Compute target filename component
if [ -z "$MP" ]
then
    RELEASE_DIRNAME=$RELEASE
    FILENAME_VER=$RELEASE
else
    RELEASE_DIRNAME=$RELEASE-$MP
    FILENAME_VER=$RELEASE-$MP
fi

# Compute destination directories
ROOT=s3://packages.couchbase.com/releases/$RELEASE_DIRNAME
RELEASE_DIR=/home/buildbot/releases/$RELEASE_DIRNAME
mkdir -p $RELEASE_DIR/ce

upload()
{
    build=$1
    target=$2
    md5file=$RELEASE_DIR/$target.md5

    if [ ! -e $md5file -o $build -nt $md5file ]
    then
        echo Creating fresh md5sum file for $build...
        md5sum $build | cut -c1-32 > /tmp/md5-$$.md5
        mv /tmp/md5-$$.md5 $md5file
    fi

    if [[ "$COMMUNITY" = "private" && "$target" =~ "community" ]]
    then
        echo Uploading $build PRIVATELY...
        perm_arg=
        ce_dir=ce/
    else
        echo Uploading $build...
        perm_arg=-P
        ce_dir=
    fi

    s3cmd sync $perm_arg $build $ROOT/$target$STAGING
    s3cmd sync $perm_arg $md5file $ROOT/$target.md5$STAGING

    echo Copying $build to releases...
    rsync -a $build $RELEASE_DIR/$ce_dir$target
}

#if [ ! -e couchbase-server_$FILENAME_VER-src.tgz ]
#then
#    echo 'Create the source tarball with create_tarball.sh!'
#    exit 1
#fi
#upload couchbase-server_$FILENAME_VER-src.tgz couchbase-server_$FILENAME_VER-src.tgz

upload couchbase-server-enterprise_centos6_x86_64_$RELEASE-$BUILD-rel.rpm.manifest.xml \
  couchbase-server-$FILENAME_VER-manifest.xml

upload couchbase-server-community_centos6_x86_64_$RELEASE-$BUILD-rel.rpm \
  couchbase-server-community-$FILENAME_VER-centos6.x86_64.rpm
upload couchbase-server-enterprise_centos6_x86_64_$RELEASE-$BUILD-rel.rpm \
  couchbase-server-enterprise-$FILENAME_VER-centos6.x86_64.rpm

upload couchbase-server-community_x86_64_$RELEASE-$BUILD-rel.rpm \
  couchbase-server-community-$FILENAME_VER-centos5.x86_64.rpm
upload couchbase-server-enterprise_x86_64_$RELEASE-$BUILD-rel.rpm \
  couchbase-server-enterprise-$FILENAME_VER-centos5.x86_64.rpm

upload couchbase-server-community_debian7_x86_64_$RELEASE-$BUILD-rel.deb \
  couchbase-server-community_$FILENAME_VER-debian7_amd64.deb
upload couchbase-server-enterprise_debian7_x86_64_$RELEASE-$BUILD-rel.deb \
  couchbase-server-enterprise_$FILENAME_VER-debian7_amd64.deb

upload couchbase-server-community_suse11_x86_64_$RELEASE-$BUILD-rel.rpm \
  couchbase-server-community-$FILENAME_VER-suse11.x86_64.rpm
upload couchbase-server-enterprise_suse11_x86_64_$RELEASE-$BUILD-rel.rpm \
  couchbase-server-enterprise-$FILENAME_VER-suse11.x86_64.rpm

upload couchbase-server-community_ubuntu_1204_x86_64_$RELEASE-$BUILD-rel.deb \
  couchbase-server-community_$FILENAME_VER-ubuntu12.04_amd64.deb
upload couchbase-server-enterprise_ubuntu_1204_x86_64_$RELEASE-$BUILD-rel.deb \
  couchbase-server-enterprise_$FILENAME_VER-ubuntu12.04_amd64.deb

upload couchbase-server-community_x86_64_$RELEASE-$BUILD-rel.deb \
  couchbase-server-community_$FILENAME_VER-ubuntu10.04_amd64.deb
upload couchbase-server-enterprise_x86_64_$RELEASE-$BUILD-rel.deb \
  couchbase-server-enterprise_$FILENAME_VER-ubuntu10.04_amd64.deb

upload couchbase-server-community_x86_64_$RELEASE-$BUILD-rel.zip \
  couchbase-server-community_$FILENAME_VER-macos_x86_64.zip
upload couchbase-server-enterprise_x86_64_$RELEASE-$BUILD-rel.zip \
  couchbase-server-enterprise_$FILENAME_VER-macos_x86_64.zip

upload couchbase_server-community-windows-amd64-$RELEASE-$BUILD.exe \
  couchbase-server-community_$FILENAME_VER-windows_amd64.exe
upload couchbase_server-enterprise-windows-amd64-$RELEASE-$BUILD.exe \
  couchbase-server-enterprise_$FILENAME_VER-windows_amd64.exe

upload couchbase_server-community-windows-x86-$RELEASE-$BUILD.exe \
  couchbase-server-community_$FILENAME_VER-windows_x86.exe
upload couchbase_server-enterprise-windows-x86-$RELEASE-$BUILD.exe \
  couchbase-server-enterprise_$FILENAME_VER-windows_x86.exe

