#!/bin/bash
#  
#  Import release packages into local debian repo.  Step 2 of three:
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
    echo "use:  `basename $0`  Release Edition"
    echo ""
    echo "      Release is build number, like 2.0.2-1234"
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
 #  echo VERSION is $VERSION
 #  echo EDITION is $EDITION
    echo ""
    }

VER_REX='[0-9]\.[0-9]\.[0-9]-[0-9]{1,}'

VERSION=$1 ; shift ; if [[ ! ${VERSION} ]] ; then read -p "Release: "  VERSION ; fi
if [[ ! ${VERSION} =~ ${VER_REX} ]]                                ; then echo "bad version" ; usage ; exit 9 ; fi
export    VERSION

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi
export    EDITION

REPO=${LOCAL_REPO_ROOT}/${EDITION}/deb
export REPO
echo "Importing into local ${EDITION} repo at ${REPO}"

reprepro -T deb -V --ignore=wrongdistribution --basedir ${REPO}  includedeb  precise couchbase-server-${EDITION}_x86_64_${VERSION}-rel.deb
reprepro -T deb -V --ignore=wrongdistribution --basedir ${REPO}  includedeb  lucid   couchbase-server-${EDITION}_x86_64_${VERSION}-rel.deb

reprepro -T deb -V --ignore=wrongdistribution --basedir ${REPO}  includedeb  precise couchbase-server-${EDITION}_x86_${VERSION}-rel.deb
reprepro -T deb -V --ignore=wrongdistribution --basedir ${REPO}  includedeb  lucid   couchbase-server-${EDITION}_x86_${VERSION}-rel.deb
