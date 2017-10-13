#!/bin/bash -e

function usage() {
    echo
    echo "$0 -r <product>  -r <release> -v <version> -b <build-number>"
    echo "where:"
    echo "  -p: product name: sync_gateway, couchbase-lite-ios"
    echo "  -r: release branch: master, 1.5.0, etc."
    echo "  -v: version number: 1.5.0, 2.0DB15, etc."
    echo "  -b: build number: 128, etc."
    echo
}

while getopts "p:r:v:b:h" opt; do
    case $opt in
        p) PRODUCT=$OPTARG;;
        r) RELEASE=$OPTARG;;
        v) VERSION=$OPTARG;;
        b) BLD_NUM=$OPTARG;;
        h|?) usage
           exit 0;;
        *) echo "Invalid argument $opt"
           usage
           exit 1;;
    esac
done

if [ "x${PRODUCT}" = "x" ]; then
    echo "Product name not set"
    usage
    exit 2
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

if [ "x${BLD_NUM}" = "x" ]; then
    echo "Build number not set"
    usage
    exit 2
fi

LB_MOUNT=/latestbuilds
if [ ! -e ${LB_MOUNT} ]; then
    echo "'latestbuilds' directory is not mounted"
    exit 3
fi

REL_MOUNT=/releases
if [ ! -e ${REL_MOUNT} ]; then
    echo "'releases' directory is not mounted"
    exit 3
fi

# Compute S3 component dirname
case "$PRODUCT" in
    sync_gateway)
        REL_DIRNAME=sync_gateway
        S3_REL_DIRNAME=couchbase-sync-gateway
        ;;
    *ios*)
        REL_DIRNAME=couchbase-lite-ios
        S3_REL_DIRNAME=couchbase-lite/ios
        ;;
    *)
        echo "Unsupported Product!"
        usage
        ;;
esac

# Compute destination directories
S3CONFIG=${HOME}/.ssh/live.s3cfg
S3_DIR=s3://packages.couchbase.com/releases/${S3_REL_DIRNAME}/${VERSION}
SRC_DIR=${LB_MOUNT}/${PRODUCT}/${RELEASE}/${BLD_NUM}
RELEASE_DIR=${REL_MOUNT}/mobile/${S3_REL_DIRNAME}/${VERSION}

if [ ! -e ${BUILD_DIR} ]; then
    echo "Given build doesn't exist: ${BUILD_DIR}"
    exit 4
fi

upload()
{
    src=${1}
    target=${1/${RELEASE}-${BLD_NUM}/${VERSION}}

    echo src: $src
    echo dest: $target

    # Verify build exists
    if [ ! -e $src ]; then
        echo "Given build doesn't exist: ${src}"
        exit 5
    fi
    echo "Uploading to ${S3_DIR}/$target ..."
    echo
    CMD="s3cmd -c $S3CONFIG sync -P $src ${S3_DIR}/$target"
    ${CMD}

    # Archive internal releases
    echo "Archiving ${src} to ${RELEASE_DIR}/$target ..."
    echo
    mkdir -p ${RELEASE_DIR}
    CMD="rsync -au $src ${RELEASE_DIR}/$target"
    ${CMD}
}

OPWD=`pwd`
finish() {
    cd $OPWD
    exit
}
trap finish EXIT

get_s3_upload_link()
{
    s3cmd ls -c $S3CONFIG ${S3_DIR}/  | cut -c 30- | sed -e 's/s3:/https:/'
}

cd ${SRC_DIR}
FILES=$(ls * |grep -v source |grep -v '.xml' |grep -v '.json' |grep -v '.properties')
for fl in $FILES; do
    upload ${fl}
done

get_s3_upload_link
