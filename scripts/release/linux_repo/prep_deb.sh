#!/bin/bash
#  
#  Create a new local debian repo.  Step 1 of four:
#  
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import packages
#   4.  upload to shared repository
#  
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi
export    LOCAL_REPO_ROOT

function usage
    {
    echo ""
    echo "use:  `basename $0`"
    echo ""
    echo "      creates dir for new local repo, adds keys and sources.list files for 'community' or 'enterprise' repositories"
    echo ""
    }

mkdir -p ${LOCAL_REPO_ROOT}/keys
cp ./couchbase-server-public-key  ${LOCAL_REPO_ROOT}/keys/couchbase-server-public-key

for EDITION in enterprise community
  do
    for UBUNTU in precise lucid
      do
        SRCL_DIR=${LOCAL_REPO_ROOT}/sources.list.d/${UBUNTU}/${EDITION}
        mkdir -p ${SRCL_DIR}
        LISTFILE=${SRCL_DIR}/couchbase-server.list
        echo "# `date`"                                                                                                 > ${LISTFILE}
        echo '# '                                                                                                      >> ${LISTFILE}
        echo '# wget http://packages.couchbase.com/releases/couchbase-server/keys/couchbase-server-public-key'         >> ${LISTFILE}
        echo '# gpg --import  couchbase-server-public-key'                                                             >> ${LISTFILE}
        echo '# cat couchbase-server-public-key  | sudo apt-key add -'                                                 >> ${LISTFILE}
        echo '# sudo apt-get update'                                                                                   >> ${LISTFILE}
        echo '# '                                                                                                      >> ${LISTFILE}
        echo 'deb  http://packages.couchbase.com/releases/couchbase-server/${EDITION}/deb/  ${UBUNTU}/${UBUNTU} main'  >> ${LISTFILE}
        echo 'deb  http://security.ubuntu.com/ubuntu  ${UBUNTU}-security  main'                                        >> ${LISTFILE}
    done
done

