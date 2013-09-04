#!/bin/bash -h
#              Download and upload to s3
#              along with .staging files

TMP_DIR=~/release_tmp

usage()
    {
    echo ""
    echo "usage:   `basename {0}` VERSION [-p PLATFORM]"
    echo ""
    echo "          VERSION             product version string"
    echo ""
    echo "          [ -M MODEL ]     android or ios.     (both if not given)"
    echo ""
    echo "          [ -m TMP_DIR  ]     temp dir to use, if not ${TMP_DIR}"
    echo ""
    echo "By default the script will handle pacakges for all platforms."
    }

if [[ $1 = "--help" ]]
then
    echo ""
    usage
    exit
fi

####    globals

builds="http://cbfs.hq.couchbase.com:8484/builds"
s3_relbucket="s3://packages.couchbase.com/releases"

####    required, positional arguments

if [ ! ${1} ]; then echo ; echo "VERSION required" ; usage ; exit ; fi

version=${1}
shift

vrs_rex='([0-9]\.[0-9])-([0-9]{1,})'

if [[ $version =~ $vrs_rex ]]
  then
    for N in 1 2 ; do
        if [[ $N -eq 1 ]] ; then rel_num=${BASH_REMATCH[$N]} ; fi
        if [[ $N -eq 2 ]] ; then bld_num=${BASH_REMATCH[$N]} ; fi
    done
else
    echo ""
    echo "bad version number: ${version}"
    usage
    exit
fi

####    optional, named arguments

while getopts "h:p:m:" OPTION; do
  case "$OPTION" in
      M)
        MODEL="$OPTARG"
        ;;
      m)
        TMP_DIR="$OPTARG"
        ;;
      h)
        usage
        exit 0
        ;;
      *)
        usage
        exit 9
        ;;
  esac
done

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

rm ~/home_phone.txt

echo "Create tmp folder to hold all the packages"
rm      -rf ${TMP_DIR}
mkdir   -p  ${TMP_DIR}
chmod   777 ${TMP_DIR}
pushd       ${TMP_DIR}  2>&1 > /dev/null

s3_target = ""

for platform_type in ${platforms[@]}; do
    if [ $platform_type == "android" ]; then
        package="cblite_android_${version}.zip"
        release="cblite_android_`echo ${version} | cut -d '-' -f1`.zip"
        s3_target="${s3_relbucket}/couchbase-lite/android/1.0-beta/"
    elif [ $platform_type == "ios" ]; then
        package="cblite_ios_${version}.zip"
        release="cblite_ios_`echo ${version} | cut -d '-' -f1`.zip"
        s3_target="${s3_relbucket}/couchbase-lite/ios/1.0-beta/"
    elif [ $platform_type == "couchbase-sync-gateway" ]; then
        package="sync_gateway_${version}.zip"
        release="sync_gateway_`echo ${version} | cut -d '-' -f1`.zip"
        s3_target="${s3_relbucket}/couchbase-sync-gateway/1.0-beta/"
    fi

    wget "${builds}/${package}"
    if [ -z `ls $package` ]; then
        echo "$package is not found on ${builds}"
        echo "Terminating the staging process"
        exit 1
    fi
    cp $package $release

    #md5?

    echo "Staging for $release"
    touch "$release.staging"

    echo $package >> ~/home_phone.txt
    rm $package
done

####    upload .staging and then the regular files

echo "Uploading .staging files to S3..."
s3cmd put -P            *.staging       "${s3_target}"

echo "Uploading packages to S3..."
s3cmd put -P `ls | grep -v staging`     "${s3_target}"

echo "Granting anonymous read access..."
s3cmd setacl --acl-public --recursive "${s3_target}"

s3cmd ls ${s3_target}
popd                 2>&1 > /dev/null
