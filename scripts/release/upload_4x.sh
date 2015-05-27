#!/bin/bash -e

# Expects to be run from the latestbuilds directory.

RELEASE=4.0.0
CODENAME=sherlock
MP=beta
BUILD=2213
STAGING=.staging
EDITIONS="enterprise"
PLATFORMS="centos6 centos7 debian7 macos oel6 opensuse11.3 ubuntu12.04 ubuntu14.04 windows"

########################################
# Don't modify anything below this line
########################################


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
mkdir -p $RELEASE_DIR

upload()
{
    build=${1/.\//}
    target=${build/$RELEASE-$BUILD/$FILENAME_VER}
    md5file=$RELEASE_DIR/$target.md5

    echo ::::::::::::::::::::::::::::::::::::::

    if [ ! -e $md5file -o $target -nt $md5file ]
    then
        echo Creating fresh md5sum file for $build...
        md5sum $build | cut -c1-32 > /tmp/md5-$$.md5
        mv /tmp/md5-$$.md5 $md5file
    fi

    echo Uploading $build...
    s3cmd sync -P $build $ROOT/$target$STAGING
    s3cmd sync -P $md5file $ROOT/$target.md5$STAGING

    echo Copying $build to releases...
    cp $build $RELEASE_DIR/$target
}

OPWD=`pwd`
finish() {
    cd $OPWD
    exit
}
trap finish EXIT

cd couchbase-server/$CODENAME/$BUILD
upload couchbase-server-$RELEASE-$BUILD-manifest.xml

for edition in $EDITIONS
do
    for platform in $PLATFORMS
    do
        for file in `find . -maxdepth 1 -name couchbase-server-${edition}\*${platform}\*`
        do
            upload $file
        done
    done
done

