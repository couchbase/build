#!/bin/bash

# this is just a helper script; rather than running each script separately just use this
#
# prereq - need createrepo, wget and s3cmd installed
#        - also need s3cmd --configure run for the user that is running this script

edition=$1
release=$2
upload=$3

function help() {
    cat <<HELP_STRING
    Usage:
        ./yum_repo.sh <edition> <release>

        <edition> - enterprise or community
        <release> - version string of the format <version>-<build> eg: 4.0.0-3010

HELP_STRING
}

if ! hash createrepo 2>/dev/null; then
    echo "createrepo is not installed"
    exit 1
fi

if ! hash wget 2>/dev/null; then
    echo "wget is not installed"
    exit 1
fi

if ! hash s3cmd 2>/dev/null; then
    echo "s3cmd is not installed"
    exit 1
fi

if [ ! -e ~/.s3cfg ]; then
    echo 's3cmd is not configured. Please run s3cmd --configure first'
    exit 1
fi

if [ "$edition" != "enterprise" -a "$edition" != "community" ]; then
    echo unknown edition
    help
    exit 1
fi

gpgkeys='79CF7903 CD406E62 D9223EDA'
for key in $gpgkeys; do
    gpg --list-secret-key $key > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Key $key not installed"
        exit 1
    fi
done

./prep_rpm.sh
./seed_rpm.sh $edition
./import_rpm.sh $release $edition
./sign_rpm.sh $release $edition
if [ "$upload" == "yes" ]; then
    ./upload_rpm.sh $edition --init
    ./upload_meta.sh --init
fi
