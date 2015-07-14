#!/bin/bash

# prereq - need createrepo, wget and s3cmd installed
# just a helper script; rather than running each script separately just use this

edition=$1
release=$2

function help() {
    cat <<HELP_STRING
    Usage:
        ./yum_repo.sh <edition> <release>
        
        <edition> - enterprise or community
        <release> - version string of the format <version>-<build> eg: 4.0.0-3010

HELP_STRING
}

if [ "$edition" != "enterprise" -a "$edition" != "community" ]; then
    echo unknown edition
    help
    exit 1
fi

./prep_rpm.sh 
./seed_rpm.sh $edition
./import_rpm.sh $release $edition
./sign_rpm.sh $release $edition
./upload_rpm.sh $edition --init
./upload_meta.sh --init
