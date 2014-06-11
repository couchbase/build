#!/bin/bash
#          
#          run from manual jobs:   prepare_release_ios_master
#                                  prepare_release_ios_100
#          
#           to download an iOS ZIP file and upload it with a new number.
#          
#          called with paramters:
#          
#            BLD_NUM       number of ZIP file to download (0.0.0-1234)
#            REL_NUM       number/name to release as      (0.0.0, 0.0.0-beta)
#            EDITION       'community' or 'enterprise'
#          
source ~/.bash_profile
set -e

PUT_CMD="s3cmd put -P"
GET_CMD="s3cmd get"

function usage
    {
    echo -e "\nuse:  ${0}   bld_to_release  release_number  edition\n\n"
    }

if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
BLD_NUM=${1}
                     vrs_rex='([0-9]{1,}\.[0-9]{1,}\.[0-9]{1,})'
if [[ ${BLD_NUM} =~ $vrs_rex  ]]
  then
    VERSION=${BASH_REMATCH[1]}
else
    echo "illegal value for BLD_NUM: "'>>'${BLD_NUM}'<<'
    exit 88
fi

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
REL_NUM=${2}

PKG_SRC=s3://packages.couchbase.com/builds/mobile/ios/${VERSION}/${BLD_NUM}
PKG_DEST=s3://packages.couchbase.com/builds/mobile/ios/${VERSION}/${REL_NUM}


if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
EDITION=${3}

IOS_ZIP_SRC=coucbase-lite-ios-${EDITION}_${BLD_NUM}.zip
IOS_ZIP_DST=coucbase-lite-ios-${EDITION}_${REL_NUM}.zip


##############################################################################   S T A R T
echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================  download ${PKG_SRC}/${IOS_ZIP_SRC}
${GET_CMD}  ${PKG_SRC}/${IOS_ZIP_SRC}
mv      ${IOS_ZIP_SRC} ${IOS_ZIP_DST}
echo ============================================  uploading ${PKG_DEST}/${IOS_ZIP_DST}
${PUT_CMD}             ${IOS_ZIP_DST}                        ${PKG_DEST}/${IOS_ZIP_DST}
echo ============================================ `date`
