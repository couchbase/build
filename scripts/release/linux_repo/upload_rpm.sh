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

REPO=/home/buildbot/couchbase-server/linux/
S3ROOT=s3://packages.couchbase.com/releases/couchbase-server/linux/

if [[ $1 == "--init" ]]
    then
    pushd ${REPO} 2>&1 >> /dev/null
    s3cmd put -v -P --recursive rpm  ${S3ROOT}
    popd          2>&1 >> /dev/null

else if [[ $1 == "--update" ]]
    then
      # s3cmd sync -P --no-delete-removed --no-check-md5 --progress --verbose  ${REPO} ${S3ROOT}
        s3cmd sync -P --no-delete-removed                --progress --verbose  ${REPO} ${S3ROOT}
    else
        echo "use:  $0  --init | --update"
        exit 9
    fi
fi

                                      # every

s3cmd setacl --acl-public --recursive s3://packages.couchbase.com/releases/couchbase-server/linux/rpm
s3cmd ls                              s3://packages.couchbase.com/releases/couchbase-server/linux/rpm
