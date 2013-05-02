#!/bin/bash
#  
#  Create a new local debian repo.  Step 1 of three:
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
    echo "use:  `basename $0`  Edition"
    echo ""
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
 #  echo EDITION is $EDITION
    echo ""
    }

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi
export    EDITION                                                   

REPO=${LOCAL_REPO_ROOT}/${EDITION}/deb                              
export REPO
echo "Creating local ${EDITION} repo at ${REPO}"


KEY=CB6EBC87

mkdir -p ${REPO}/keys
mkdir -p ${REPO}/conf

OUTFILE=${REPO}/conf/distributions

echo "writing ${OUTFILE}"

echo "Origin: couchbase"                                            >> ${OUTFILE}
echo "SignWith: ${KEY}"                                             >> ${OUTFILE}
echo "Suite: precise"                                               >> ${OUTFILE}
echo "Codename: precise"                                            >> ${OUTFILE}
echo "Version: 12.04"                                               >> ${OUTFILE}
echo "Components: precise/main"                                     >> ${OUTFILE}
echo "Architectures: amd64 i386 source"                             >> ${OUTFILE}
echo "Description: Couchbase Community Repository"                  >> ${OUTFILE}
echo ""                                                             >> ${OUTFILE}
echo "Origin: couchbase"                                            >> ${OUTFILE}
echo "SignWith: ${KEY}"                                             >> ${OUTFILE}
echo "Suite: lucid"                                                 >> ${OUTFILE}
echo "Codename: lucid"                                              >> ${OUTFILE}
echo "Version: 10.04"                                               >> ${OUTFILE}
echo "Components: lucid/main"                                       >> ${OUTFILE}
echo "Architectures: amd64 i386 source"                             >> ${OUTFILE}
echo "Description: Couchbase Community Repository "                 >> ${OUTFILE}

cp ./couchbase-server-public-key  ${REPO}/keys/couchbase-server-public-key
