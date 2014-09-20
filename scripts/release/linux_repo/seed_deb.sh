#!/bin/bash
#  
#  Create a new local debian repo.  Step 2 of five:
#  
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import packages
#   4.  upload to shared repository
#   5.  upload keys and sources files
#  
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi

function usage
    {
    echo ""
    echo "use:  `basename $0`  Edition"
    echo ""
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
    echo ""
    }

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[ ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi

if [[ ${EDITION} == 'community'  ]] ; then EDITION_NAME='Community Edition'  ; fi
if [[ ${EDITION} == 'enterprise' ]] ; then EDITION_NAME='Enterprise Edition' ; fi


REPO=${LOCAL_REPO_ROOT}/${EDITION}/deb                              

echo "Creating local ${EDITION} repo at ${REPO}"

KEY=805A4A3A

mkdir -p ${REPO}/conf

OUTFILE=${REPO}/conf/distributions

echo "writing ${OUTFILE}"

echo "# `date`"                                                      > ${OUTFILE}
echo "Origin: couchbase"                                            >> ${OUTFILE}
echo "SignWith: ${KEY}"                                             >> ${OUTFILE}
echo "Suite: precise"                                               >> ${OUTFILE}
echo "Codename: precise"                                            >> ${OUTFILE}
echo "Version: 12.04"                                               >> ${OUTFILE}
echo "Components: precise/main"                                     >> ${OUTFILE}
echo "Architectures: amd64 source"                                  >> ${OUTFILE}
echo "Description: Couchbase ${EDITION_NAME} Repository"            >> ${OUTFILE}
echo ""                                                             >> ${OUTFILE}
echo "Origin: couchbase"                                            >> ${OUTFILE}
echo "SignWith: ${KEY}"                                             >> ${OUTFILE}
echo "Suite: lucid"                                                 >> ${OUTFILE}
echo "Codename: lucid"                                              >> ${OUTFILE}
echo "Version: 10.04"                                               >> ${OUTFILE}
echo "Components: lucid/main"                                       >> ${OUTFILE}
echo "Architectures: amd64 source"                                  >> ${OUTFILE}
echo "Description: Couchbase ${EDITION_NAME} Repository "           >> ${OUTFILE}
echo ""                                                             >> ${OUTFILE}
echo "Origin: couchbase"                                            >> ${OUTFILE}
echo "SignWith: ${KEY}"                                             >> ${OUTFILE}
echo "Suite: wheezy"                                                >> ${OUTFILE}
echo "Codename: wheezy"                                             >> ${OUTFILE}
echo "Version: 7.0"                                                 >> ${OUTFILE}
echo "Components: wheezy/main"                                      >> ${OUTFILE}
echo "Architectures: amd64 source"                                  >> ${OUTFILE}
echo "Description: Couchbase ${EDITION_NAME} Repository "           >> ${OUTFILE}

echo "" 
echo "Ready to import into repositories under ${LOCAL_REPO_ROOT}"
echo "" 
