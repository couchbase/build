#!/bin/bash
#  
#  Create a new local yum repo.  Step 1 of six:
#  
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import packages
#   4.  sign packges in local repo
#   5.  upload local repo to shared repository
#   6.  upload keys and yum.repos.d
#  
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi
export    LOCAL_REPO_ROOT

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi

mkdir -p ${LOCAL_REPO_ROOT}/keys
cp ./couchbase-server-public-key     ${LOCAL_REPO_ROOT}/keys/couchbase-server-public-key
cp ./couchbase-server-public-key-v3  ${LOCAL_REPO_ROOT}/keys/couchbase-server-public-key-v3

mkdir -p ${LOCAL_REPO_ROOT}/yum.repos.d/enterprise
mkdir -p ${LOCAL_REPO_ROOT}/yum.repos.d/community

for CENTOS in 5 6
  do
    if [[ ${CENTOS} -eq 5 ]] ; then KEYFILE=couchbase-server-public-key-v3 ; fi
    if [[ ${CENTOS} -eq 6 ]] ; then KEYFILE=couchbase-server-public-key    ; fi
    
    SRCL_DIR=${LOCAL_REPO_ROOT}/yum.repos.d/${ED}
    mkdir -p ${SRCL_DIR}
    REPOLIST=${SRCL_DIR}/couchbase-server.repo
    echo "# `date`"                                                                                                   > ${REPOLIST}
    echo '# '                                                                                                        >> ${REPOLIST}
    echo '[couchbase]'                                                                                               >> ${REPOLIST}
    echo 'name=Couchbase Server'                                                                                     >> ${REPOLIST}
    echo 'baseurl=http://packages.couchbase.com/releases/couchbase-server/${EDITION}/rpm/\$releasever/\$$basearch/'  >> ${REPOLIST}
    echo 'enabled=1'                                                                                                 >> ${REPOLIST}
    echo 's3_enabled=1'                                                                                              >> ${REPOLIST}
    echo 'gpgcheck=1'                                                                                                >> ${REPOLIST}
    echo 'gpgkey=http://packages.couchbase.com/releases/couchbase-server/keys/${KEYFILE}'                            >> ${REPOLIST}
done

