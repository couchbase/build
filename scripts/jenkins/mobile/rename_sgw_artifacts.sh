#!/bin/bash
#          
#          run from manual jobs:   rename_sgw_artifacts_master
#                                  rename_sgw_artifacts_100
#          
#           to download an Sync Gateway ZIP file and upload it with a new number.
#          
#          called with paramters:
#          
#            BLD_NUM       number of ZIP file to download (0.0.0-1234)
#            REL_NUM       number/name to release as      (0.0.0, 0.0.0-beta)
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

PKG_SRC=s3://packages.couchbase.com/builds/mobile/sync_gateway/${VERSION}/${BLD_NUM}
PKG_DEST=s3://packages.couchbase.com/builds/mobile/sync_gateway/${VERSION}/${REL_NUM}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
EDITION=${3}

if [[ ${EDITION} =~ 'community' ]]
  then
    SGW_SRC_LIST="                                                                \
                 couchbase-sync-gateway_${BLD_NUM}_i386-community.rpm       \
                 couchbase-sync-gateway_${BLD_NUM}_x86_64-community.rpm      \
                 couchbase-sync-gateway_${BLD_NUM}_i386-community.deb         \
                 couchbase-sync-gateway_${BLD_NUM}_amd64-community.deb         \
                 couchbase-sync-gateway_${BLD_NUM}_macosx_x86_64-community.rpm  \
                 setup_couchbase-sync-gateway_${BLD_NUM}_x86-community.rpm       \
                 setup_couchbase-sync-gateway_${BLD_NUM}_amd64-community.rpm      \
                 "
else
    SGW_SRC_LIST="                                                      \
                 couchbase-sync-gateway_${BLD_NUM}_i386.rpm       \
                 couchbase-sync-gateway_${BLD_NUM}_x86_64.rpm      \
                 couchbase-sync-gateway_${BLD_NUM}_i386.deb         \
                 couchbase-sync-gateway_${BLD_NUM}_amd64.deb         \
                 couchbase-sync-gateway_${BLD_NUM}_macosx_x86_64.rpm  \
                 setup_couchbase-sync-gateway_${BLD_NUM}_x86.rpm       \
                 setup_couchbase-sync-gateway_${BLD_NUM}_amd64.rpm      \
                 "
fi


##############################################################################   S T A R T
echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

for PKG in ${SGW_SRC_LIST}
  do
    NEW_PKG=`echo ${PKG} | sed "s/${BLD_NUM}/${REL_NUM}/"`
    echo ============================================ download ${PKG_SRC}/${PKG}
    ${GET_CMD}  ${PKG_SRC}/${PKG}
    mv          ${PKG} ${NEW_PKG}
    echo ============================================== upload ${PKG_DEST}/${NEW_PKG}
    ${PUT_CMD}         ${NEW_PKG}                              ${PKG_DEST}/${NEW_PKG}
    echo
done

echo ============================================ `date`
