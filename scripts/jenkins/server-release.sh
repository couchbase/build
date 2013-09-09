#!/bin/bash
#              use to remote .staging file from S3,
#              leaving uploaded packages and md5 files

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

latestbuilds="http://builds.hq.northscale.net/latestbuilds"
s3_relbucket="s3://packages.couchbase.com/releases"

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

if [[ -e ${phone_home} ]] ; then rm  ${phone_home} ; fi

declare	-A decorout
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
                staging="couchbase-server-${name}_${rel_num}_${arch[$platform]}.${package_type}.staging"
                echo "Remove staging file for $staging and ready for release"
                s3cmd del ${s3_target}${staging}
                
                if [[ $package_type == deb || $package_type == rpm ]]
                   then
                    staging="couchbase-server-${name}_${rel_num}_${arch[$platform]}_${decorout[$package_type]}.${package_type}.staging"
                    echo "Remove staging file for $staging and ready for release"
                    s3cmd del ${s3_target}${staging}
                fi
            fi
        done
    done
done

for name in ${names[@]} ; do
    if [[ $name == "community" ]]
        then
        staging=couchbase-server_src-${rel_num}.tar.gz.staging
        echo "Remove staging file for $staging and ready for release"
        s3cmd del ${s3_target}${staging}
    fi
done

s3cmd ls ${s3_target}

