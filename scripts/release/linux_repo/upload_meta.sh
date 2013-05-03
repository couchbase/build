#!/bin/bash
#  
#  Upload local debian repo to shared repo.  Step 5 of five:
#  
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import packages
#   4.  upload to shared repository
#   5.  upload keys and sources files
#  
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi

function usage
    {
    echo ""
    echo "use:  `basename $0`  [ --init | --update ]"
    echo ""
    echo "to upload keys and sources.list.d files to S3."
    echo ""
    echo "      use --init   to create the S3 bucket and upload from local repo"
    echo "      use --update to add files from local repo to the S3 bucket"
    echo ""
    echo "This step should be performed after both debain repos are uploaded."
    echo ""
    }


REPO=${LOCAL_REPO_ROOT}/${EDITION}/deb

S3ROOT=s3://packages.couchbase.com/releases/couchbase-server

echo "Uploading local ${EDITION} repo at ${REPO} to ${S3ROOT}"


if [[ $1 == "--init" ]]
    then
    pushd ${LOCAL_REPO_ROOT} 2>&1 >> /dev/null
    s3cmd put -v -P --recursive keys            ${S3ROOT}
    s3cmd put -v -P --recursive sources.list.d  ${S3ROOT}
    popd                     2>&1 >> /dev/null

else if [[ $1 == "--update" ]]
    then
      # s3cmd sync -P --no-delete-removed --no-check-md5 --progress --verbose  ${LOCAL_REPO_ROOT}/keys            ${S3ROOT}/keys
        s3cmd sync -P --no-delete-removed                --progress --verbose  ${LOCAL_REPO_ROOT}/keys            ${S3ROOT}/keys
        s3cmd sync -P --no-delete-removed                --progress --verbose  ${LOCAL_REPO_ROOT}/sources.list.d  ${S3ROOT}/sources.list
    else
        usage
        exit 9
    fi
fi


s3cmd setacl --acl-public --recursive ${S3ROOT} 
s3cmd ls                              ${S3ROOT}
