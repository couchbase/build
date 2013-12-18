#!/bin/bash
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
    echo ""
    echo "         [ -m TMP_DIR  ]   temp dir to use, if not ${TMP_DIR}"
    echo ""
    echo "         [ -h          ]   print this help message"
    echo ""
    echo "By default the script will handle packages for all editions, platforms and package types."
    echo ""
    exit 4
    }
if [[ $1 == "--help" ]] ; then usage ; fi


####    globals

s3_relbucket=s3://packages.couchbase.com/releases

phone_home=${WORKSPACE}/home_phone.txt


####    required, positional arguments

if [ !  ${1} ] ; then echo ; echo "VERSION required" ; usage ; fi

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
latestbuilds=http://builds.hq.northscale.net/latestbuilds/${rel_num}

#                                     must end with "/"
s3_target=${s3_relbucket}/${rel_num}/


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


if [[ -e ${phone_home} ]] ; then rm  ${phone_home} ; fi

if [[ -e  ${TMP_DIR}   ]] ; then rm -rf ${TMP_DIR} ; fi
mkdir -p  ${TMP_DIR}
chmod 777 ${TMP_DIR}
pushd     ${TMP_DIR} 2>&1 > /dev/null

                                                 #  decorated package names
declare	-A decor_in decorout
decor_in[deb]=ubuntu_1204
decor_in[rpm]=centos6
decorout[deb]=openssl098
decorout[rpm]=openssl098
                                                 #  map platform to arch
declare -A arch
arch[32]=x86
arch[64]=x86_64
                                                 #  package is what is produced by build
                                                 #  release is what is uploaded to S3
for         package_type in ${types[@]}     ; do
    for     name         in ${names[@]}     ; do
        for platform     in ${platforms[@]} ; do
            if [ $platform -eq 32 ] && [ $package_type == "zip" ]; then
                echo "MAC package doesn't support 32 bit platform"
            else
                package=couchbase-server-${name}_${arch[$platform]}_${version}.${package_type}
                if [[ $package_type == deb || $package_type == rpm ]]
                  then
                    release=couchbase-server-${name}_${rel_num}_${arch[$platform]}_${decorout[$package_type]}.${package_type}
                else
                    release=couchbase-server-${name}_${rel_num}_${arch[$platform]}.${package_type}
                fi
                
                wget --no-verbose ${latestbuilds}/${package}
                if [ ! -e $package ]
                    then
                    echo "$package is not found on ${latestbuilds}"
                    echo "Terminate the staging process"
                    exit 1
                fi
                #wget  --no-verbose ${latestbuilds}/${package}.manifest.xml
         echo   cp $package $release  >> ${phone_home}
                cp $package $release
                #cp $package.manifest.xml $release.manifest.xml
                
                echo "Calculate md5sum for $release"
                md5sum $release > $release.md5
                
                echo "Staging for $release"
                touch $release.staging
                #touch $release.manifest.xml.staging
                echo $release >> ${phone_home}
                rm $package
                #rm $package.manifest.xml
            fi
            if [[ $package_type == deb || $package_type == rpm ]]
                then
                package=couchbase-server-${name}_${decor_in[$package_type]}_${arch[$platform]}_${version}.${package_type}
                release=couchbase-server-${name}_${rel_num}_${arch[$platform]}.${package_type}
                
                wget --no-verbose ${latestbuilds}/${package}
                if [ ! -e $package ]
                    then
                    echo "$package is not found on ${latestbuilds}"
                    echo "Terminate the staging process"
                    exit 1
                fi
                #wget --no-verbose ${latestbuilds}/${package}.manifest.xml
         echo   cp $package $release >> ${phone_home}
                cp $package $release
                #cp $package.manifest.xml $release.manifest.xml
                
                echo "Calculate md5sum for $release"
                md5sum $release > $release.md5
                
                echo "Staging for $release"
                touch $release.staging
                #touch $release.manifest.xml.staging
                echo $release >> ${phone_home}
                rm $package
                #rm $package.manifest.xml
            fi
        done
    done
done

srcpkg=couchbase-server_src-${bld_num}.tar.gz
dstpkg=couchbase-server_src-${rel_num}.tar.gz

for name in ${names[@]}; do
    if [ "community" = $name ]; then
        wget --no-verbose  -O ${dstpkg}  ${latestbuilds}/${srcpkg}
        if [[ ! -s ${dstpkg} ]]
            then
            echo "${srcpkg} not found on ${latestbuilds}"
            echo "Terminate the staging process"
            exit 7
        fi
        touch  ${dstpkg}.staging
        md5sum ${dstpkg} > ${dstpkg}.md5
    fi
done

####    upload .staging and then regular files

echo "Uploading .staging files to S3..."
s3cmd put -P             *.staging    ${s3_target}

echo "Uploading packages to S3..."
s3cmd put -P `ls | grep -v staging`   ${s3_target}

echo "Granting anonymous read access..."
s3cmd setacl --acl-public --recursive ${s3_target}

s3cmd ls ${s3_target}
popd                 2>&1 > /dev/null
