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
if [[ ${0} == '-bash' ]]
    then                      # called with  . path/to/this.sh
    THISFILE=prep_deb.sh
    DO_EXIT=0
  else                        # called as      path/to/this.sh
    THISFILE=`basename $0`
    DO_EXIT=1
fi
function quit  {  if [[ ${DO_EXIT} == 1 ]] ; then exit 0 ; fi }


if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi

function usage
    {
    echo ""
    echo "use:  .  ${THISFILE}      [ LOCAL_REPO_ROOT ] , where"
    echo ""
    echo "             LOCAL_REPO_ROOT   OPTIONAL: the directory to contain directories keys/ and"
    echo "                               sources.list.d/, and the enterprise and community repositories"
    echo ""
    echo "                               If not given, default is ${LOCAL_REPO_ROOT}"
    echo ""
    echo ""
    echo "      Creates dir for new local repo, adds keys and yum.repos files for 'community' or"
    echo "      'enterprise' repositories.  The debian and rpm repositories can share a ROOT."
    echo ""
    echo "      NOTE:  If you specify a LOCAL_REPO_ROOT, use the  \". ${THISFILE}\" form so that it will"
    echo "             export this to the environment of the calling shell, and will be known to"
    echo "             downstream processes.  These other scripts will assume the default if not set"
    echo "             as an environment variable."
    echo ""
    echo ""
    quit
    }
if [[ ${1} =~ '-h' || ${1} =~ '-H' ]] ; then usage ; fi

if [[ ${1} ]] ;  then  LOCAL_REPO_ROOT=${1} ; fi


function write_keys
    {
    mkdir -p ${LOCAL_REPO_ROOT}/keys
    cp ./couchbase-server-public-key     ${LOCAL_REPO_ROOT}/keys/couchbase-server-public-key
    cp ./couchbase-server-public-key-v3  ${LOCAL_REPO_ROOT}/keys/couchbase-server-public-key-v3
    }

function write_sources
    {
    for EDITION in enterprise community
      do
        for CENTOS in 5 6
          do
            if [[ ${CENTOS} -eq 5 ]] ; then KEYFILE=couchbase-server-public-key-v3 ; fi
            if [[ ${CENTOS} -eq 6 ]] ; then KEYFILE=couchbase-server-public-key    ; fi
            
            YUM_DIR=${LOCAL_REPO_ROOT}/yum.repos.d/${EDITION}
            mkdir -p ${YUM_DIR}
            REPOFILE=${YUM_DIR}/couchbase-server.repo
            echo "# `date`"                                                                                                   > ${REPOFILE}
            echo '# '                                                                                                        >> ${REPOFILE}
            echo '[couchbase]'                                                                                               >> ${REPOFILE}
            echo 'name=Couchbase Server'                                                                                     >> ${REPOFILE}
            echo 'baseurl=http://packages.couchbase.com/releases/couchbase-server/'${EDITION}'/rpm/$releasever/$basearch/'   >> ${REPOFILE}
            echo 'enabled=1'                                                                                                 >> ${REPOFILE}
            echo 's3_enabled=1'                                                                                              >> ${REPOFILE}
            echo 'gpgcheck=1'                                                                                                >> ${REPOFILE}
            echo 'gpgkey=http://packages.couchbase.com/releases/couchbase-server/keys/'${KEYFILE}                            >> ${REPOFILE}
        done
    done
    }

if [[    -e  ${LOCAL_REPO_ROOT} ]]
  then
    echo ""
    read -p "${LOCAL_REPO_ROOT} already exists.  Delete? " YESNO
    echo ""
    if [[ ${YESNO} =~ 'y' || ${YESNO} =~ 'Y' ]] ; then echo "replacing ${LOCAL_REPO_ROOT}" ;  rm  -rf  ${LOCAL_REPO_ROOT} ; fi
fi
export        LOCAL_REPO_ROOT=${LOCAL_REPO_ROOT}


write_keys
write_sources

echo "" 
echo "Ready to seed repositories under ${LOCAL_REPO_ROOT}"
echo "" 
