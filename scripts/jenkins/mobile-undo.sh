#!/bin/bash

usage()
    {
    echo ""
    echo "usage:"
    echo ""
    echo '  [ MODEL=<platform>]     ./auto_undo <VERSION>'
    echo ""
    echo 'where     MODEL           is: "android" or "ios" or "couchbase-sync-gateway"'
    echo ""
    echo '          VERSION         is: product release number'
    echo ""
    echo "If any optional environment variable is not set, then all values are used"
    }

if [ $# -eq 0 ]; then
    echo "Version number is not provided"
    usage
    exit
fi

if [ $1 = "--help" ] || [ $1 = "-h" ]; then
    usage
    exit
fi

VERSION=${1}

if [ -z "$MODEL" ]; then
    echo "Stage packages for all types"
    platforms=("android" "ios" "couchbase-sync-gateway")
elif [ $MODEL == "all" ]; then
    echo "Stage packages for all types"
    platforms=("android" "ios" "couchbase-sync-gateway")
else
    echo "Stage packages for $MODEL"
    platforms=$MODEL

echo "==============================================="
for platform_type in ${platforms[@]};do
    if [ $platform_type == "android" ]; then
        base_name="cblite_android_${VERSION}.zip"
    elif [ $platform_type == "ios" ]; then
        base_name="cblite_ios_${VERSION}.zip"
    elif [ $platform_type == "couchbase-sync-gateway" ]; then
        base_name="sync_gateway_${VERSION}.zip"
    fi
    echo "Removing the specific packages from S3"
    s3cmd del "s3://packages.couchbase.com/releases/${VERSION}/${base_name}"
    s3cmd del "s3://packages.couchbase.com/releases/${VERSION}/${base_name}.staging"
done
