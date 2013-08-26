#!/bin/bash -h
#              use to download from latestbuilds and upload to S3,
#              along with md5 and .staging files

TMP_DIR=~/release_tmp

usage()
    {
    echo ""
    echo "usage:  `basename $0`  VERSION  [ -e EDITION -p PLATFORM -t TYPE ]"
    echo ""
    echo "           VERSION         product version string, of the form 2.0.2-769-rel"
    echo ""
    echo "         [ -e EDITION  ]   community or enterprise.  (both if not given)"
    echo "         [ -p PLATFORM ]   32 or 64.                 (both if not given)"
    echo "         [ -t TYPE     ]   rpm, deb, setup.exe, zip  (all if not given)"
    echo "         [ -o OS_TYPE  ]   0, 1                      (for newer and older if not given)"
    echo ""
    echo "         [ -m TMP_DIR  ]   temp dir to use, if not ${TMP_DIR}"
    echo ""
    echo "         [ -h          ]   print this help message"
    echo ""
    echo "By default the script will handle packages for all editions, platforms and package types."
    }

if [[ $1 == "--help" ]]
    then
    echo ""
    usage
    exit
fi

####    globals

latestbuilds="http://builds.hq.northscale.net/latestbuilds"
s3_relbucket="s3://packages.couchbase.com/releases"

####    required, positional arguments

if [ !  ${1} ] ; then echo ; echo "VERSION required" ; usage ; exit ; fi

version=${1}
shift

vrs_rex='([0-9]\.[0-9]\.[0-9])-([0-9]{1,})-rel'

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
    
#                                     must end with "/"
s3_target="${s3_relbucket}/${rel_num}/"


####    optional, named arguments

while getopts "he:p:t:m:" OPTION; do
  case "$OPTION" in
    e)
      NAME="$OPTARG"
      ;;
    p)
      PLATFORM="$OPTARG"
      ;;
    t)
      TYPE="$OPTARG"
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


if [ -z "$TYPE" ]; then
    echo "Stage packages for all types"
    types=("rpm" "deb" "setup.exe" "zip")
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

if [ -z "$OS_TYPE" ]; then
    echo "Stage for newer and older packages"
    os_types=(0 1)
else
    os_types=$OS_TYPE
fi

rm ~/home_phone.txt

echo "Create tmp folder to hold all the packages"
rm   -rf  ${TMP_DIR}
mkdir -p  ${TMP_DIR}
chmod 777 ${TMP_DIR}
pushd     ${TMP_DIR} 2>&1 > /dev/null

for package_type in ${types[@]}; do
    for platform in ${platforms[@]}; do
        for name in ${names[@]}; do
            for os_type in ${os_types[@]}; do
                if [ $platform -eq 32 ] && [ $package_type == "zip" ]; then
                    echo "MAC package doesn't support 32 bit platform"
                else
                    if [ $platform -eq 32 ]; then
                        if [ $os_type -eq 0 ]; then
                            package="couchbase-server-${name}_x86_${version}.${package_type}"
                            release="couchbase-server-${name}_x86_`echo ${version} | cut -d '-' -f1`.${package_type}"
                        else
                            package="couchbase-server-${name}_x86_${version}_openssl098e.${package_type}"
                            release="couchbase-server-${name}_x86_`echo ${version} | cut -d '-' -f1`_openssl098e.${package_type}"
                        fi
                    else
                        if [ $os_type -eq 0 ]; then
                            package="couchbase-server-${name}_x86_${platform}_${version}.${package_type}"
                            release="couchbase-server-${name}_x86_${platform}_`echo ${version} | cut -d '-' -f1`.${package_type}"
                        else
                            package="couchbase-server-${name}_x86_${platform}_${version}_openssl098e.${package_type}"
                            release="couchbase-server-${name}_x86_${platform}_`echo ${version} | cut -d '-' -f1`_openssl098e.${package_type}"
                        fi
                    fi

                    wget "${latestbuilds}/${package}"
                    if [ -z `ls $package` ]; then
                        echo "$package is not found on ${latestbuilds}"
                        echo "Terminate the staging process"
                        exit 1
                    fi
                    #wget "${latestbuilds}/${package}.manifest.xml"
                    cp $package $release
                    #cp "$package.manifest.xml" "$release.manifest.xml"

                    echo "Calculate md5sum for $release"
                    md5sum $release > "$release.md5"

                    echo "Staging for $release"
                    touch "$release.staging"
                    #touch "$release.manifest.xml.staging"
                    echo $package >> ~/home_phone.txt
                    rm $package
                    #rm "$package.manifest.xml"
                fi
            done
        done
    done
done

srcpkg=couchbase-server_src-${bld_num}.tar.gz
dstpkg=couchbase-server_src-${rel_num}.tar.gz

for name in ${names[@]}; do
    if [ "community" = $name ]; then
        wget    -O ${dstpkg}  ${latestbuilds}/${srcpkg}
        if [[ ! -s ${dstpkg} ]]
            then
            echo "${srcpkg} not found on ${latestbuilds}"
            echo "Terminate the staging process"
            exit 7
        fi
        touch  ${dstpkg}.staging
        md5sum ${dstpkg} > "${dstpkg}.md5"
    fi
done

####    upload .staging and then regular files

echo "Uploading .staging files to S3..."
s3cmd put -P             *.staging    "${s3_target}"

echo "Uploading packages to S3..."
s3cmd put -P `ls | grep -v staging`   "${s3_target}"

echo "Granting anonymous read access..."
s3cmd setacl --acl-public --recursive "${s3_target}"

s3cmd ls ${s3_target}
popd                 2>&1 > /dev/null
