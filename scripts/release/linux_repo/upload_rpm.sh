#!/bin/bash
#  
#  Upload local repo to S3.  Step 5 of six:
#  
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import packages
#   4.  sign packges in local repo
#   5.  upload local repo to shared repository
#   6.  upload keys and yum.repos.d
#  
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi

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

REPO=${LOCAL_REPO_ROOT}/${EDITION}/rpm

S3ROOT=s3://packages.couchbase.com/releases/couchbase-server/${EDITION}/rpm

echo "Uploading local ${EDITION} repo at ${REPO} to ${S3ROOT}"

if [[ $1 == "--init" ]]
    then
    pushd ${LOCAL_REPO_ROOT}/${EDITION} 2>&1 >> /dev/null
    s3cmd put -v -P --recursive rpm  ${S3ROOT}
    popd                                2>&1 >> /dev/null

else if [[ $1 == "--update" ]]
    then
      # s3cmd sync -P --no-delete-removed --no-check-md5 --progress --verbose  ${REPO} ${S3ROOT}/
        s3cmd sync -P --no-delete-removed                --progress --verbose  ${REPO} ${S3ROOT}/
    else
        echo "use:  $0  --init | --update"
        exit 9
    fi
fi

s3cmd setacl --acl-public --recursive ${S3ROOT} 
s3cmd ls                              ${S3ROOT}
