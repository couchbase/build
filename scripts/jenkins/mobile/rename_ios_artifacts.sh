#!/bin/bash
#          
#          run from manual jobs:   rename_ios_artifacts_master
#                                  rename_ios_artifacts_100
#          
#           to download an iOS ZIP file and upload it with a new number.
#          
#          called with paramters:
#          
#            branch name          master, release/1.0.0, etc.
#            BLD_TO_RELEASE       number of ZIP file to download (0.0.0-1234)
#            RELEASE_NUMBER       number/name to release as      (0.0.0, 0.0.0-beta)
#            EDITION              'community' or 'enterprise'
#          
source ~/.bash_profile
set -e

PUT_CMD="s3cmd put -P"
GET_CMD="s3cmd get"

function usage
    {
    echo -e "\nuse:  ${0}   branch  bld_to_release  release_number  edition\n\n"
    }

if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
BLD_TO_RELEASE=${2}

vrs_rex='([0-9]{1,}\.[0-9]{1,}\.[0-9]{1,})'
if [[ ${BLD_TO_RELEASE} =~ $vrs_rex  ]]
  then
    VERSION=${BASH_REMATCH[1]}
else
    echo "illegal value for BLD_TO_RELEASE: "'>>'${BLD_TO_RELEASE}'<<'
    exit 88
fi

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
RELEASE_NUMBER=${3}

PKG_SRC=s3://packages.couchbase.com/builds/mobile/ios/${VERSION}/${BLD_TO_RELEASE}
PKG_DEST=s3://packages.couchbase.com/builds/mobile/ios/${VERSION}/${RELEASE_NUMBER}


if [[ ! ${4} ]] ; then usage ; exit 66 ; fi
EDITION=${4}

if [[ ${EDITION} =~ 'community' ]]
  then
    IOS_ZIP_SRC=cblite-ios-${BLD_TO_RELEASE}-${EDITION}.zip
    IOS_ZIP_DST=cblite-ios-${RELEASE_NUMBER}-${EDITION}.zip
else
    IOS_ZIP_SRC=cblite-ios-${BLD_TO_RELEASE}.zip
    IOS_ZIP_DST=cblite-ios-${RELEASE_NUMBER}.zip
fi


##############################################################################   S T A R T
echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================  download ${PKG_SRC}/${IOS_ZIP_SRC}
${GET_CMD}  ${PKG_SRC}/${IOS_ZIP_SRC}
mv      ${IOS_ZIP_SRC} ${IOS_ZIP_DST}
echo ============================================  uploading ${PKG_DEST}/${IOS_ZIP_DST}
${PUT_CMD}             ${IOS_ZIP_DST}                        ${PKG_DEST}/${IOS_ZIP_DST}
echo ============================================ `date`
