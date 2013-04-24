#!/bin/bash

usage(){
    echo "Usage:"
    echo "./auto_staging {VERSION}"
    echo "By default the script will handle packages for all names, platform and package types"
    echo "If you want to specify platform, name or types, usage is:"
    echo "NAME={NAME} PLATFORM={PLATFORM} TYPE={TYPE} ./auto_staging {VERSION}"
}

if [ $# -eq 0 ]; then
    echo "Build number is not provided"
    exit
fi

if [ $1 = "--help" ] || [ $1 = "-h" ]; then
    usage
    exit
fi

if [ -z "$TYPE" ]; then
    echo "Stage packages for all types"
    types=("rpm" "deb" "setup.exe")
else
    echo "Stage packages for $TYPE"
    types=$TYPE
fi

if [ -z "$PLATFORM" ]; then
    echo "Stage packages for both 32 and 64 bits"
    platforms=(32 64)
else
    echo "Stage packages for $PLATFORM"
    platforms=$PLATFORM
fi

if [ -z "$NAME" ]; then
    echo "Stage packages for both enterprise and community editions"
    names=("enterprise" "community")
else
    echo "Stage packages for $NAME"
    names=$NAME
fi

echo "Create tmp folder to hold all the packages"
user=`whoami`
if [ $user = "root" ]; then
    rm -r ~/release_tmp
    mkdir ~/release_tmp
    chmod 777 ~/release_tmp
else
    sudo rm -r ~/release_tmp
    sudo mkdir ~/release_tmp
    sudo chmod 777 ~/release_tmp
fi
cd ~/release_tmp

for package_type in ${types[@]}; do
    for platform in ${platforms[@]}; do
        for name in ${names[@]}; do
            if [ $platform -eq 32 ]; then
                package="couchbase-server-${name}_x86_${1}.${package_type}"
                release="couchbase-server-${name}_x86_`echo ${1} | cut -d '-' -f1`.${package_type}"
            else
                package="couchbase-server-${name}_x86_${platform}_${1}.${package_type}"
                release="couchbase-server-${name}_x86_${platform}_`echo ${1} | cut -d '-' -f1`.${package_type}"
            fi

            wget "http://builds.hq.northscale.net/latestbuilds/$package"
            #wget "http://builds.hq.northscale.net/latestbuilds/$package.manifest.xml"
            cp $package $release
            #cp "$package.manifest.xml" "$release.manifest.xml"

            echo "Calculate md5sum for $release"
            md5sum $release > "$release.md5"

            echo "Staging for $release"
            touch "$release.staging"
            #touch "$release.manifest.xml.staging"
            rm $package
            #rm "$package.manifest.xml"
        done
    done
done

echo "Start uploading packages to S3 server"
s3cmd put -P * "s3://packages.couchbase.com/releases/`echo ${1} | cut -d '-' -f1`/"
