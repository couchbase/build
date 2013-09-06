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

sync_types=("rpm" "deb" "zip")
sync_platforms=("x86" "x86_64")
android_check=0
ios_check=0

for platform_type in ${platforms[@]}; do
    for s_type in ${sync_types[@]}; do
        for s_pl in ${sync_platforms[@]}; do
            if [ $platform_type == "android" ]; then
                if [ $android_check -eq 0 ]; then
                    staging="couchbase-lite-community-android_`echo {1} | cut -d '-' -f1`-beta.zip.staging"
                    path="couchbase-lite/android/1.0-beta"
                    android_check=1
                else
                    continue
                fi
            elif [ $platform_type == "ios" ]; then
                if [ $ios_check -eq 0 ]; then
                    staging="couchbase-lite-community-ios_`echo {1} | cut -d '-' -f1`-beta.zip.staging"
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
                    staging="couchbase-sync-gateway-community_`echo {1} | cut -d '-' -f1`-beta_${s_pl}.${s_type}.staging"
                    path="couchbase-sync-gateway/1.0-beta"
                fi
            fi
            echo "Removing staging file for $staging and ready fo release"
            s3cmdl del "s3://packages.couchbase.com/releases/${path}/${staging}"
        done
    done
done
