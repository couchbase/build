#!/bin/bash
#  
#  Create a new local yum repo.  Step 1 of four:
#  
#   1.  seed new repo
#   2.  import packages
#   3.  sign packges in local repo
#   4.  upload local repo to shared repository
#  
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi
export    LOCAL_REPO_ROOT

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi


REPO=${LOCAL_REPO_ROOT}/${EDITION}/rpm
export REPO

rm   -rf ${REPO}
mkdir -p ${REPO}
mkdir -p ${REPO}/5/x86_64
mkdir -p ${REPO}/5/i386
mkdir -p ${REPO}/6/x86_64
mkdir -p ${REPO}/6/i386

createrepo --verbose  ${REPO}/5/x86_64
createrepo --verbose  ${REPO}/6/x86_64

createrepo --verbose  ${REPO}/5/i386
createrepo --verbose  ${REPO}/6/i386

