#!/bin/bash
#  
#  Upload local debian repo to shared repo.  Step 3 of three:
#  
#   1.  seed new repo
#   2.  import packages
#   3.  upload to shared repository
#  
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi
export    LOCAL_REPO_ROOT

function usage
    {
    echo ""
    echo "use:  `basename $0`  Release Edition [ --init | --update ]"
    echo ""
    echo "      Release is build number, like 2.0.2-1234"
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
    echo "      use --init   to create the S3 bucket and upload from local repo"
    echo "      use --update to add files from local repo to the S3 bucket"
    echo ""
  # echo VERSION is $VERSION
  # echo EDITION is $EDITION
    echo ""
    }

VER_REX='[0-9]\.[0-9]\.[0-9]-[0-9]{1,}'

VERSION=$1 ; shift ; if [[ ! ${VERSION} ]] ; then read -p "Release: "  VERSION ; fi
if [[ ! ${VERSION} =~ ${VER_REX} ]]                                ; then echo "bad version" ; usage ; exit 9 ; fi
export    VERSION

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi
export    EDITION

REPO=${LOCAL_REPO_ROOT}/${EDITION}/deb

S3ROOT=s3://packages.couchbase.com/releases/couchbase-server/${EDITION}/deb

echo "Uploading local ${EDITION} repo at ${REPO} to ${S3ROOT}"


if [[ $1 == "--init" ]]
    then
    pushd ${REPO} 2>&1 >> /dev/null
    s3cmd put -v -P --recursive deb  ${S3ROOT}
    popd          2>&1 >> /dev/null

else if [[ $1 == "--update" ]]
    then
      # s3cmd sync -P --no-delete-removed --no-check-md5 --progress --verbose  ${REPO}  ${S3ROOT}
        s3cmd sync -P --no-delete-removed                --progress --verbose  ${REPO}  ${S3ROOT}
    else
        echo "use:  $0  --init | --update"
        exit 9
    fi
fi

                                      # every

s3cmd setacl --acl-public --recursive ${S3ROOT} 
s3cmd ls                              ${S3ROOT}
