#!/bin/bash -e

function usage() {
    echo
    echo "$0 -r <release-code-name> -v <version-number> -b <build-number>"
    echo "   [-m <MP-number> [-c <community-status>] [-p <platforms>] [-l] [-s]"
    echo "where:"
    echo "  -r: release code name; watson or sherlock"
    echo "  -v: version number; eg. 4.1.1"
    echo "  -b: build number"
    echo "  -m: MP number; eg MP-1 [optional]"
    echo "  -c: community-status; defaults to 'private' to make it non-downloadable."
    echo "      set it to any other string to make it public [optional]"
    echo "  -p: specific platforms to upload. By default uploads all platforms."
    echo "      Pass -p multiple times for multiple platforms [optional]"
    echo "  -l: Push it to live (production) s3. Default is to push to staging [optional]"
    echo "  -s: strip '-enterprise' from the filename [optional]"
    echo
}

DEFAULT_PLATFORMS=(centos6 centos7 debian8 debian7 macos oel6 suse11 ubuntu12.04 ubuntu14.04 windows)
MP=
LIVE=false

# Set to "private" to keep community builds non-downloadable
COMMUNITY=private

# Set to "true" to remove -enterprise from upload filenames
# (which will also prevent -community builds from being uploaded)
STRIP_ENTERPRISE=false

while getopts "r:v:b:m:c:p:lsh?" opt; do
    case $opt in
        r) RELEASE=$OPTARG;;
        v) VERSION=$OPTARG;;
        b) BUILD=$OPTARG;;
        m) MP=$OPTARG;;
        c) COMMUNITY=$OPTARG;;
        p) PLATFORMS+=("$OPTARG");;
        l) LIVE=true;;
        s) STRIP_ENTERPRISE=true;;
        h|?) usage
           exit 0;;
        *) echo "Invalid argument $opt"
           usage
           exit 1;;
    esac
done

if [ ${#PLATFORMS[@]} -eq 0 ]; then
    PLATFORMS=("${DEFAULT_PLATFORMS[@]}")
fi

if [ "x${RELEASE}" = "x" ]; then
    echo "Release code name not set"
    usage
    exit 2
fi

if [ "x${VERSION}" = "x" ]; then
    echo "Version number not set"
    usage
    exit 2
fi

if [ "x${BUILD}" = "x" ]; then
    echo "Build number not set"
    usage
    exit 2
fi

if ! [[ $VERSION =~ ^[0-9]*\.[0-9]*\.[0-9]*$ ]]
then
    echo "Version number format incorrect. Correct format is A.B.C where A, B and C are integers."
    exit 3
fi

if ! [[ $BUILD =~ ^[0-9]*$ ]]
then
    echo "Build number must be an integer"
    exit 3
fi


RELEASES_MOUNT=/releases
if [ ! -e ${RELEASES_MOUNT} ]; then
    echo "'releases' directory is not mounted"
    exit 4
fi

LB_MOUNT=/latestbuilds
if [ ! -e ${LB_MOUNT} ]; then
    echo "'latestbuilds' directory is not mounted" 
    exit 4
fi


# Compute target filename component
if [ -z "$MP" ]
then
    RELEASE_DIRNAME=$VERSION
    FILENAME_VER=$VERSION
else
    RELEASE_DIRNAME=$VERSION-$MP
    FILENAME_VER=$VERSION-$MP
fi

# Compute destination directories
S3CONFIG=~/.ssh/staging.s3cfg
ROOT=s3://staging.packages.couchbase.com/releases/$RELEASE_DIRNAME
RELEASE_DIR=${RELEASES_MOUNT}/staging/$RELEASE_DIRNAME
if [[ "$LIVE" = "true" ]]
then
    S3CONFIG=~/.ssh/live.s3cfg
    ROOT=s3://packages.couchbase.com/releases/$RELEASE_DIRNAME
    RELEASE_DIR=${RELEASES_MOUNT}/$RELEASE_DIRNAME
fi

# Create destination directory, including "hidden" ce subdir
mkdir -p $RELEASE_DIR/ce

upload()
{
    build=${1/.\//}
    target=${build/$VERSION-$BUILD/$FILENAME_VER}
    if [[ "$STRIP_ENTERPRISE" = "true" ]]
    then
        if [[ "$target" =~ "community" ]]
        then
            echo "STRIP_ENTERPRISE set, skipping $target"
            return
        else
            target=${target/-enterprise/}
        fi
    fi

    echo ::::::::::::::::::::::::::::::::::::::

    md5file=$RELEASE_DIR/$target.md5
    if [ ! -e $md5file -o $build -nt $md5file ]
    then
        echo Creating fresh md5sum file for $build...
        md5sum $build | cut -c1-32 > /tmp/md5-$$.md5
        mv /tmp/md5-$$.md5 $md5file
    fi

    sha256file=$RELEASE_DIR/$target.sha256
    if [ ! -e $sha256file -o $build -nt $sha256file ]
    then
        echo Creating fresh sha256sum file for $build...
        sha256sum $build | cut -c1-64 > /tmp/sha256-$$.sha256
        mv /tmp/sha256-$$.sha256 $sha256file
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
    s3cmd -c $S3CONFIG sync $perm_arg $build $ROOT/$target
    s3cmd -c $S3CONFIG sync $perm_arg $md5file $ROOT/$target.md5
    s3cmd -c $S3CONFIG sync $perm_arg $sha256file $ROOT/$target.sha256

    echo Copying $build to releases...
    rsync -a $build $RELEASE_DIR/$ce_dir$target
}

OPWD=`pwd`
finish() {
    cd $OPWD
    exit
}
trap finish EXIT

if [ ! -e ${LB_MOUNT}/couchbase-server/$RELEASE/$BUILD ]; then
    echo "Given build doesn't exist: ${LB_MOUNT}/couchbase-server/$RELEASE/$BUILD"
    exit 5
fi

cd ${LB_MOUNT}/couchbase-server/$RELEASE/$BUILD
upload couchbase-server-$VERSION-$BUILD-manifest.xml

for edition in enterprise community
do
    for platform in ${PLATFORMS[@]}
    do
        for file in `find . -maxdepth 1 -name couchbase-server-${edition}\*${platform}\*`
        do
            upload $file
        done
    done
done

