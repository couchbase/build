#!/bin/bash
#
#  Upload local debian repo to shared repo.  Step 4 of five:
#
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import packages
#   4.  upload to shared repository
#   5.  upload keys and sources files
#
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server                        ; fi
if [[ ! ${S3_PACKAGE_ROOT} ]] ; then  S3_PACKAGE_ROOT=s3://packages.couchbase.com/releases/couchbase-server ; fi

function usage
{
    echo ""
    echo "use:  `basename $0`  Edition [ --init | --update ]"
    echo ""
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
    echo "      use --init   to create the S3 bucket and upload from local repo"
    echo "      use --update to add files from local repo to the S3 bucket"
    echo ""
    echo ""
}

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi


if [[ $1 == "--init" ]]
then
    REPO=${LOCAL_REPO_ROOT}/${EDITION}
    S3ROOT=${S3_PACKAGE_ROOT}/${EDITION}
    echo "Uploading local ${EDITION} repo at ${REPO}/deb to ${S3ROOT}/deb"

    pushd ${REPO}                                  2>&1 >> /dev/null
    s3cmd put -v -P --recursive  deb  ${S3ROOT}/
    popd                                           2>&1 >> /dev/null

else if [[ $1 == "--update" ]]
    then
        REPO=${LOCAL_REPO_ROOT}/${EDITION}/deb/*
        S3ROOT=${S3_PACKAGE_ROOT}/${EDITION}/deb
        echo "Uploading local ${EDITION} repo at ${REPO} to ${S3ROOT}"

      # s3cmd sync -P --no-delete-removed --no-check-md5 --progress --verbose  ${REPO}  ${S3ROOT}/
        s3cmd sync -P --no-delete-removed                --progress --verbose  ${REPO}  ${S3ROOT}/

    else
        usage
        exit 9
    fi
fi


s3cmd setacl --acl-public --recursive ${S3ROOT}
s3cmd ls                              ${S3ROOT}
