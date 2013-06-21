#!/bin/bash

usage()
    {
    echo ""
    echo "usage:"
    echo ""
    echo '   [ NAME=<edition>       ] \'
    echo '   [ PLATFORM=<bit-width> ]  \'
    echo '   [ TYPE=<package_type>  ]   ./auto_undo <VERSION>'
    echo ""
    echo 'where   edition      is: "enterprise" or "community"'
    echo '        bit-width    is: "32" or "64"'
    echo '        package_type is: "rpm", "deb", or "setup.exe"'
    echo ""
    echo '        VERSION      is: product release number, like 2.1.0'
    echo ""
    echo "If any optional environment variable is not set, then all values are used."
    echo ""
    }

if [ $# -eq 0 ]; then
    echo "Build number is not provided"
    usage
    exit
fi

if [ $1 = "--help" ] || [ $1 = "-h" ]; then
    usage
    exit
fi
VERSION=${1}

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

echo "==============================================="
for package_type in ${types[@]}; do
    for platform in ${platforms[@]}; do
        for name in ${names[@]}; do
            if [ $platform -eq 32 ]; then
                base_name="couchbase-server-${name}_x86_${VERSION}.${package_type}"
            else
                base_name="couchbase-server-${name}_x86_64_${VERSION}.${package_type}"
            fi
            echo "Removing all $name  $package_type files from S3"
            s3cmd del "s3://packages.couchbase.com/releases/${VERSION}/${base_name}"
            s3cmd del "s3://packages.couchbase.com/releases/${VERSION}/${base_name}.md5"
            s3cmd del "s3://packages.couchbase.com/releases/${VERSION}/${base_name}.manifest.xml"
            s3cmd del "s3://packages.couchbase.com/releases/${VERSION}/${base_name}.manifest.xml.md5"
            echo "-----------------------------------------------"
            base_name=couchbase-server_src-${VERSION}.tar.gz
            s3cmd del "s3://packages.couchbase.com/releases/${VERSION}/${base_name}"
            s3cmd del "s3://packages.couchbase.com/releases/${VERSION}/${base_name}.md5"
            s3cmd del "s3://packages.couchbase.com/releases/${VERSION}/${base_name}.staging"
            echo "==============================================="
        done
    done
done
