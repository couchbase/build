#!/bin/bash
#  
#  Create a new local debian and rpm repos for OpenSSL libraries.  Step 1 of five:
#  
#   1.  prepare local openssl098 repos
#   2.  seed new repos
#   3.  import packages
#   4.  sign RPM packges in local repos
#   5.  upload local repos to shared repository
#  
if [[ ${0} == '-bash' ]]
    then                      # called with  . path/to/this.sh
    THISFILE=prep_ssl.sh
    DO_EXIT=0
  else                        # called as      path/to/this.sh
    THISFILE=`basename $0`
    DO_EXIT=1
fi
function quit  {  if [[ ${DO_EXIT} == 1 ]] ; then exit 0 ; fi }


if [[ ! ${LOCAL_SSL_ROOT} ]] ; then  LOCAL_SSL_ROOT=~/linux_repos/openssl098 ; fi

function usage
    {
    echo ""
    echo "use:  .  ${THISFILE}      [ LOCAL_SSL_ROOT ] , where"
    echo ""
    echo "             LOCAL_SSL_ROOT    OPTIONAL: the directory to contain directories keys/ and"
    echo "                               sources.list.d/, and the enterprise and community repositories"
    echo ""
    echo "                               If not given, default is ${LOCAL_SSL_ROOT}"
    echo ""
    echo ""
    echo "      Creates dir for new local repo, adds keys and yum.repos files for 'community' or"
    echo "      'enterprise' repositories.  The debian and rpm repositories can share a ROOT."
    echo ""
    echo "      NOTE:  If you specify a LOCAL_SSL_ROOT, use the  \". ${THISFILE}\" form so that it will"
    echo "             export this to the environment of the calling shell, and will be known to"
    echo "             downstream processes.  These other scripts will assume the default if not set"
    echo "             as an environment variable."
    echo ""
    echo ""
    quit
    }
if [[ ${1} =~ '-h' || ${1} =~ '-H' ]] ; then usage ; fi

if [[ ${1} ]] ;  then  LOCAL_SSL_ROOT=${1} ; fi


if [[    -e  ${LOCAL_SSL_ROOT} ]]
  then
    echo ""
    read -p "${LOCAL_SSL_ROOT} already exists.  Delete? " YESNO
    echo ""
    if [[ ${YESNO} =~ 'y' || ${YESNO} =~ 'Y' ]] ; then echo "replacing ${LOCAL_SSL_ROOT}" ;  rm  -rf  ${LOCAL_SSL_ROOT} ; fi
  else
    echo "creating ${LOCAL_SSL_ROOT}"
    mkdir -p       ${LOCAL_SSL_ROOT}
fi
export        LOCAL_SSL_ROOT=${LOCAL_SSL_ROOT}


echo "" 
echo "Ready to seed repositories under ${LOCAL_SSL_ROOT}"
echo "" 
