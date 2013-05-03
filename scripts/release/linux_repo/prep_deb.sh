#!/bin/bash
#  
#  Create a new local debian repo.  Step 1 of five:
#  
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import packages
#   4.  upload to shared repository
#   5.  upload keys and sources files
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


                       LOCAL_REPO_ROOT=~/linux_repos/couchbase-server 
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
    echo "      Creates dir for new local repo, adds keys and sources.list files for 'community' or"
    echo "      'enterprise' repositories.  The debian and rpm repositories cand share a ROOT."
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
    cp ./couchbase-server-public-key  ${LOCAL_REPO_ROOT}/keys/couchbase-server-public-key
    }

function write_sources
    {
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
            echo "deb  http://packages.couchbase.com/releases/couchbase-server/${EDITION}/deb/  ${UBUNTU}/${UBUNTU} main"  >> ${LISTFILE}
            echo "deb  http://security.ubuntu.com/ubuntu  ${UBUNTU}-security  main"                                        >> ${LISTFILE}
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
