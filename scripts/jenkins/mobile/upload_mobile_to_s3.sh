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

REL_MOUNT=/releases
if [ ! -e ${REL_MOUNT} ]; then
    echo "'releases' directory is not mounted"
    exit 4
fi

# Compute S3 component dirname
case "$RELEASE" in
    sync_gateway)
        REL_DIRNAME=sync_gateway
        S3_REL_DIRNAME=couchbase-sync-gateway
        ;;
    *android*)
        REL_DIRNAME=couchbase-lite/android
        S3_REL_DIRNAME=couchbase-lite/android
        ;;
    *java*)
        REL_DIRNAME=couchbase-lite/java
        S3_REL_DIRNAME=couchbase-lite/java
        ;;
    *ios*)
        REL_DIRNAME=couchbase-lite
        S3_REL_DIRNAME=couchbase-lite
        ;;
    *)
        usage
        ;;
esac

# Compute destination directories
S3CONFIG=~/.ssh/live.s3cfg
ROOT=s3://packages.couchbase.com/releases/$S3_REL_DIRNAME
BUILD_DIR=${LB_MOUNT}/$RELEASE/$VERSION
RELEASE_DIR=${REL_MOUNT}/mobile/$VERSION/$REL_DIRNAME

upload()
{
    build=${1}
    target=${2}
    echo src: $build
    echo dst: $target
    echo UPLOAD ::::::::::::::::::::::::::::::::::::::

    # Verify build exists
    if [ ! -e $build ]; then
        echo "Given build doesn't exist: ${build}"
        exit 5
    fi

    s3cmd -c $S3CONFIG sync -P $build $target
}

archive_rel()
{
    build=${1}
    target=${2}
    echo src: $build
    echo dst: $target
    echo ARCHIVE ::::::::::::::::::::::::::::::::::::::

    # Verify build exists
    if [ ! -e $build ]; then
        echo "Given build doesn't exist: ${build}"
        exit 5
    fi

    # Archive internal releaess
    mkdir -p $target
    rsync -au $build $target
}

OPWD=`pwd`
finish() {
    cd $OPWD
    exit
}
trap finish EXIT

cd ${BUILD_DIR}

if [[ $RELEASE =~ "couchbase-lite-ios" ]]
then
    for platform in ${PLATFORMS[@]}
    do
        SRC_DIR=$BUILD_DIR/$platform/$BUILD/
        REL_DIR=$RELEASE_DIR/$platform/
        S3_DIR=$ROOT/$platform/$VERSION/

        archive_rel $SRC_DIR $REL_DIR
        upload $SRC_DIR $S3_DIR
    done
else
    SRC_DIR=$BUILD_DIR/$BUILD/
    REL_DIR=$RELEASE_DIR/
    S3_DIR=$ROOT/$VERSION/

    archive_rel $SRC_DIR $REL_DIR
    upload $SRC_DIR $S3_DIR
fi

