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

sync_types=("rpm" "deb" "zip")
sync_platforms=("x86" "x86_64")
android_check=0
ios_check=0

echo "==============================================="
for platform_type in ${platforms[@]};do
    for s_type in ${sync_types[@]};do
        for s_pl in ${sync_platforms[@]}; do
            if [ $platform_type == "android" ]; then
                if [ $android_check -eq 0 ]; then
                    base_name="couchbase-lite-community-android_`echo ${VERSION} | cut -d '-' -f1`-beta.zip"
                    path="couchbase-lite/android/1.0-beta"
                    android_check=1
                else
                    continue
                fi
            elif [ $platform_type == "ios" ]; then
                if [ $ios_check -eq 0 ]; then
                    base_name="couchbase-lite-community-ios_`echo ${VERSION} | cut -d '-' -f1`-beta.zip"
                    path="couchbase-lite/ios/1.0-beta"
                    ios_check=1
                else
                    continue
                fi
            elif [ $platform_type == "couchbase-sync-gateway" ]; then
                 if [ $s_pl == "x86_64" ] && [ $s_type == "zip" ]; then
                    echo "Do nothing for .zip with x86_64"
                    continue
                else
                    base_name="couchbase-sync-gateway-community_`echo ${VERSION} | cut -d '-' -f1`-beta_${s_pl}.${s_type}"
                    path="couchbase-sync-gateway/1.0-beta"
                fi
            fi
            echo "Removing the specific packages from S3"
            s3cmd del "s3://packages.couchbase.com/releases/${path}/${base_name}"
            s3cmd del "s3://packages.couchbase.com/releases/${path}/${base_name}.staging"
        done
    done
done
