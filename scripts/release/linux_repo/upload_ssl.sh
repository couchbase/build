#!/bin/bash
#  
#  Upload openssl098 files from local debian/rpm repos to shared location on S3.
#  
#  Step 5 of five.
#  
#   1.  prepare local openssl098 repos
#   2.  seed new repos
#   3.  import packages
#   4.  sign RPM packges in local repos
#   5.  upload local repos to shared repository
#  
if [[ ! ${LOCAL_SSL_ROOT} ]] ; then  LOCAL_SSL_ROOT=~/linux_repos/openssl098 ; fi

function usage
    {
    echo ""
    echo "use:  `basename $0`  [ --init | --update ]"
    echo ""
    echo "to upload openssl098 files to S3"
    echo ""
    echo "      use  --init    to create the S3 bucket and upload from local openssl098 repo"
    echo "      use  --update  to add files from local openssl098 repo to the S3 bucket"
    echo ""
    echo ""
    }


S3ROOT=s3://packages.couchbase.com/releases/openssl098

echo "Uploading local openssl098 repo at ${LOCAL_SSL_ROOT} to ${S3ROOT}"


if [[ $1 == "--init" ]]
    then
    pushd ${LOCAL_SSL_ROOT} 2>&1 >> /dev/null
    s3cmd put -v -P --recursive deb             ${S3ROOT}/
    s3cmd put -v -P --recursive rpm             ${S3ROOT}/
    popd                    2>&1 >> /dev/null

else if [[ $1 == "--update" ]]
    then
      # s3cmd sync -P --no-delete-removed --no-check-md5 --progress --verbose  ${LOCAL_SSL_ROOT}/deb    #  ${S3ROOT}/deb/  #
        s3cmd sync -P --no-delete-removed                --progress --verbose  ${LOCAL_SSL_ROOT}/deb       ${S3ROOT}/deb/
        s3cmd sync -P --no-delete-removed                --progress --verbose  ${LOCAL_SSL_ROOT}/rpm       ${S3ROOT}/rpm/
    else
        usage
        exit 9
    fi
fi


s3cmd setacl --acl-public --recursive ${S3ROOT}/
s3cmd ls                              ${S3ROOT}/
