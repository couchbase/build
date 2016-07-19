#!/bin/bash -e

function usage() {
    echo
    echo "$0 -r <product> -v <version> -b <build-number>"
    echo "where:"
    echo "  -r: product; sync_gateway, couchbase-lite-ios, couchbase-lite-android, couchbase-lite-java, couchbase-lite-net"
    echo "  -v: version number; eg. 1.3.0"
    echo "  -b: build number"
    echo
}

# couchbase-lite-ios specifics
DEFAULT_PLATFORMS=(ios macosx tvos)

while getopts "r:v:b:h" opt; do
    case $opt in
        r) RELEASE=$OPTARG;;
        v) VERSION=$OPTARG;;
        b) BUILD=$OPTARG;;
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
    echo "Release product name not set"
    usage
    exit 2
fi

if [ "x${VERSION}" = "x" ]; then
    echo "Version number not set"
    usage
    exit 2
fi

if ! [[ $VERSION =~ ^[0-9]*\.[0-9]*\.[0-9]*$ ]]
then
    echo "Version number format incorrect. Correct format is A.B.C where A, B and C are integers."
    exit 3
fi

if [ "x${BUILD}" = "x" ]; then
    echo "Build number not set"
    usage
    exit 2
fi

if ! [[ $BUILD =~ ^[0-9]*$ ]]
then
    echo "Build number must be an integer"
    exit 3
fi

# Verify /latestbuilds exists
LB_MOUNT=/latestbuilds
if [ ! -e ${LB_MOUNT} ]; then
    echo "'latestbuilds' directory is not mounted"
    exit 4
fi

# Compute S3 component dirname
case "$RELEASE" in
    sync_gateway)
        S3_REL_DIRNAME=couchbase-sync-gateway
        ;;
    *android*)
        S3_REL_DIRNAME=couchbase-lite/android
        ;;
    *java*)
        S3_REL_DIRNAME=couchbase-lite/java
        ;;
    *ios*)
        S3_REL_DIRNAME=couchbase-lite
        ;;
    *)
        usage
        ;;
esac

# Compute destination directories
S3CONFIG=~/.ssh/live.s3cfg
ROOT=s3://packages.couchbase.com/releases/$S3_REL_DIRNAME
RELEASE_DIR=${LB_MOUNT}/$RELEASE/$VERSION

upload()
{
    build=${1}
    target=${2}
    echo src: $build
    echo dst: $target
    echo ::::::::::::::::::::::::::::::::::::::

    # Verify build exists
    if [ ! -e $build ]; then
        echo "Given build doesn't exist: ${build}"
        exit 5
    fi

    s3cmd -c $S3CONFIG sync -P $build $target
}

OPWD=`pwd`
finish() {
    cd $OPWD
    exit
}
trap finish EXIT

cd ${RELEASE_DIR}

if [[ $RELEASE =~ "couchbase-lite-ios" ]]
then
    for platform in ${PLATFORMS[@]}
    do
        SRC_DIR=$RELEASE_DIR/$platform/$BUILD/
        DST_DIR=$ROOT/$platform/$VERSION/
        upload $SRC_DIR $DST_DIR
    done
else
    SRC_DIR=$RELEASE_DIR/$BUILD/
    DST_DIR=$ROOT/$VERSION/
    upload $SRC_DIR $DST_DIR
fi

