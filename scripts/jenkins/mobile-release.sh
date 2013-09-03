#!/bin/bash

usage(){
    echo "Usage:"
    echo "./mobile_release {VERSION}."
    echo "By default the script will handle packages for both android and ios"
    echo "Platform can be android or ios"
    echo "MODEL={MODEL} ./mobile_release {VERSION}"
}

if [ $# -eq 0 ]; then
    echo "Version number is not provided"
    exit
fi

if [ $1 = "--help" ] || [ $1 = "-h" ]; then
    usage
    exit
fi

if [ -z "$MODEL" ]; then
    echo "Stage packages for android, ios and couchbase-sync-gateway"
    platforms=("android" "ios" "couchbase-sync-gateway")
elif [ $MODEL == "all" ]; then
    echo "Stage packages for android, ios and couchbase-sync-gateway"
    platforms=("android" "ios" "couchbase-sync-gateway")
else
    echo "Stage packages for $MODEL"
    platforms=$MODEL
fi

for platform_type in ${platforms[@]}; do
    if [ $platform_type == "android" ]; then
        staging="cblite_android_{1}.zip.staging"
    elif [ $platform_type == "ios" ]; then
        staging="cblite_ios_{1}.zip.staging"
    elif [ $platform_type == "sync_gateway" ]; then
        staging="sync_gateway_{1}.zip.staging"
    fi

    echo "Removing staging file for $staging and ready fo release"
    s3cmdl del "s3://packages.couchbase.com/releases/${platform_type}/${staging}"
done
