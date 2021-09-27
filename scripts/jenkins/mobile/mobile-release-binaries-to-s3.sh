#!/bin/bash -e

function usage() {
    echo
    echo "$0 -r <product>  -r <release> -v <version> -b <build-number>"
    echo "where:"
    echo "  -p: product name: sync_gateway, couchbase-lite-ios"
    echo "  -r: release branch: master, 1.5.0, etc."
    echo "  -v: version number: 1.5.0, 2.0DB15, etc."
    echo "  -b: build number: 128, etc."
    echo "  -c: how to handle community builds [optional]:"
    echo "        public: publicly accessible [default]"
    echo "        private: uploaded but not downloadable"
    echo "        none: do NOT upload to s3"
    echo
}

COMMUNITY=public

while getopts "p:r:v:b:c:h" opt; do
    case $opt in
        p) PRODUCT=$OPTARG;;
        r) RELEASE=$OPTARG;;
        v) VERSION=$OPTARG;;
        b) BLD_NUM=$OPTARG;;
        c) COMMUNITY=$OPTARG;;
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
        S3_REL_DIRNAME=couchbase-sync-gateway
        ;;
    *ios)
        REL_DIRNAME=ios
        if [[ ${RELEASE} == 1.* ]]; then
            S3_REL_DIRNAME=couchbase-lite/ios
        else
            S3_REL_DIRNAME=couchbase-lite-ios
        fi
        ;;
    couchbase-lite-c)
        S3_REL_DIRNAME=couchbase-lite-c
        ;;
    *tvos)
        PRODUCT=couchbase-lite-ios
        REL_DIRNAME=tvos
        S3_REL_DIRNAME=couchbase-lite/tvos
        ;;
    *macosx)
        PRODUCT=couchbase-lite-ios
        REL_DIRNAME=macosx
        S3_REL_DIRNAME=couchbase-lite/macosx
        ;;
    couchbase-lite-android)
        if [[ ${RELEASE} == 1.* ]]; then
            S3_REL_DIRNAME=couchbase-lite/android
        else
            S3_REL_DIRNAME=couchbase-lite-android
        fi
        ;;
    couchbase-lite-android-ee)
        S3_REL_DIRNAME=couchbase-lite-android-ee
        ;;
    *java)
        if [[ ${RELEASE} == 1.* ]]; then
            S3_REL_DIRNAME=couchbase-lite/java
        else
            S3_REL_DIRNAME=couchbase-lite-java
        fi
        ;;
    *net)
        REL_DIRNAME=couchbase-lite-net
        if [[ ${RELEASE} == 1.* ]]; then
            S3_REL_DIRNAME=couchbase-lite/net
        else
            S3_REL_DIRNAME=couchbase-lite-net
        fi
        ;;
    *log)
        REL_DIRNAME=couchbase-lite-log
        S3_REL_DIRNAME=couchbase-lite-log
        ;;
    *cblite)
        REL_DIRNAME=couchbase-lite-cblite
        S3_REL_DIRNAME=couchbase-lite-cblite
        ;;
    couchbase-lite-phonegap)
        S3_REL_DIRNAME=couchbase-lite-phonegap
        ;;
    *)
        echo "Unsupported Product!"
        usage
        ;;
esac

# Compute destination directories
S3_DIR=s3://packages.couchbase.com/releases/${S3_REL_DIRNAME}/${VERSION}
RELEASE_DIR=${REL_MOUNT}/mobile/${S3_REL_DIRNAME}/${VERSION}

if [[ ${STAGE} == "true" ]]
then
    S3_DIR=s3://packages-staging.couchbase.com/releases/${S3_REL_DIRNAME}/${VERSION}
    RELEASE_DIR=${REL_MOUNT}/mobile/staging/${S3_REL_DIRNAME}/${VERSION}
fi

# Fix the latestbuilds path for ios 1.4.x
if [[ ${PRODUCT} == *ios ]] && [[ ${RELEASE} == 1.* ]]; then
    SRC_DIR=${LB_MOUNT}/${PRODUCT}/${RELEASE}/${REL_DIRNAME}/${BLD_NUM}
elif [[ ${PRODUCT} == couchbase-lite-net ]]; then
    SRC_DIR=${LB_MOUNT}/${PRODUCT}/${RELEASE}/${BLD_NUM}/release
else
    SRC_DIR=${LB_MOUNT}/${PRODUCT}/${RELEASE}/${BLD_NUM}
fi

if [ ! -e ${BUILD_DIR} ]; then
    echo "Given build doesn't exist: ${BUILD_DIR}"
    exit 4
fi

upload()
{

    echo "Uploading ${RELEASE_DIRNAME} to ${S3_DIR} ..."
    echo

    # Upload EE first
    aws s3 sync ${UPLOAD_TMP_DIR} ${S3_DIR}/ --acl public-read --exclude "*" --include "*enterprise*" --include "*Enterprise*" --include "*ee*" --exclude "CBLTestServer*" --exclude "test-reports*" --exclude "analysis-reports*" --exclude "testserver*"

    # Upload CE files
    case ${COMMUNITY} in
        "private") ACL="private";;
        "none") ACL="";;  #don't need to set ACL since we are not going to upload CE files
        *) ACL="public-read";;
    esac

    if [[ ! -z $ACL ]]; then
        echo "Community builds are uploaded in $ACL mode ..."
        aws s3 sync ${UPLOAD_TMP_DIR} ${S3_DIR}/ --acl $ACL --exclude "*enterprise*" --exclude "*Enterprise*" --exclude "*ee*" --exclude "CBLTestServer*" --exclude "test-reports*" --exclude "analysis-reports*" --exclude "testserver*"
    else
        echo "Community builds are not uploaded..."
    fi

    # Archive internal releases
    echo "Archiving ${UPLOAD_TMP_DIR} to ${RELEASE_DIR} ..."
    echo
    mkdir -p ${RELEASE_DIR}
    rsync -au ${UPLOAD_TMP_DIR}/* ${RELEASE_DIR}/
}

OPWD=`pwd`
finish() {
    cd $OPWD
    exit
}
trap finish EXIT

get_s3_upload_link()
{
    set +e
    s3links=`aws s3 ls ${S3_DIR}/ | awk -v s3dir=${S3_DIR} '{print s3dir "/" $4}' | sed -e 's/s3:/https:/'`
    ignorefiles="md5\|centos8\|ubuntu14\|doc\|carthage"

    eelinks=`echo "${s3links}" | grep -v "${ignorefiles}" | grep -i "-enterprise\|-EE"`
    celinks=`echo "${s3links}" | grep -v "${ignorefiles}" | grep -v -i "-enterprise\|-EE"`

    echo "${PRODUCT} ${VERSION} build #${BLD_NUM} on s3:\n"
    if [ ! -z "${eelinks}" ]; then
        echo "enterprise:\n"
        echo "${eelinks}"
        echo "\n"
    fi
    if [ ! -z "${celinks}" ]; then
        echo "community:\n"
        echo "${celinks}"
        echo "\n"
    fi
}

cd ${SRC_DIR}
FILES=$(ls -Iblackduck | egrep -v 'source|\.xml|\.json|\.properties|\.md5|\.sha|coverage|CHANGELOG|changes\.log|unsigned|logtest|litetest|symbols|Package.swift')
UPLOAD_TMP_DIR=/tmp/${RELEASE}-${BLD_NUM}
rm -rf ${UPLOAD_TMP_DIR} && mkdir -p ${UPLOAD_TMP_DIR}
cd ${UPLOAD_TMP_DIR}
for fl in $FILES; do
    target_file=${fl/${RELEASE}-${BLD_NUM}/${VERSION}}
    echo "Copying ${SRC_DIR}/${fl} to $target_file ..."
    cp ${SRC_DIR}/${fl} ${target_file}
    echo "Generating sha256 on $target_file ..."
    sha256sum ${target_file} > ${target_file}.sha256
done

echo "Uploading files from ${UPLOAD_TMP_DIR} ..."
upload
rm -rf ${UPLOAD_TMP_DIR}

get_s3_upload_link

