#!/bin/bash
#  
#  Create a new local yum repo.  Step 3 of six:
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

function usage
    {
    echo ""
    echo "use:  `basename $0`  Release Edition"
    echo ""
    echo "      Release is build number, like 2.0.2-1234"
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
    echo VERSION is $VERSION
    echo EDITION is $EDITION
    echo ""
    }

VER_REX='([0-9]\.[0-9]\.[0-9)]-[0-9]{1,}'

VERSION=$1 ; shift ; if [[ ! ${VERSION} ]] ; then read -p "Release: "  VERSION ; fi
if [[ ! ${VERSION} =~ ${VER_REX} ]]                                ; then echo "bad version" ; usage ; exit 9 ; else BASEV=${BASE_REMATCH}[0] ; fi
export    VERSION

echo BASEV is $BASEV
exit

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi
export    EDITION

REPO=${LOCAL_REPO_ROOT}/${EDITION}/rpm
export REPO


cp couchbase-server-community_x86_64_${VERSION}-rel.rpm  /home/buildbot/couchbase-server/linux/rpm/5/i386/couchbase-server-community_${BASEV}.x86_64.rpm
cp couchbase-server-community_x86_64_${VERSION}-rel.rpm  /home/buildbot/couchbase-server/linux/rpm/6/i386/couchbase-server-community_${BASEV}.x86_64.rpm
    
cp couchbase-server-community_x86_${VERSION}-rel.rpm     /home/buildbot/couchbase-server/linux/rpm/5/i386/couchbase-server-community_${BASEV}.i386.rpm
cp couchbase-server-community_x86_${VERSION}-rel.rpm     /home/buildbot/couchbase-server/linux/rpm/6/i386/couchbase-server-community_${BASEV}.i386.rpm


createrepo --update  ${REPO}/5/x86_64
createrepo --update  ${REPO}/6/x86_64

createrepo --update  ${REPO}/5/i386
createrepo --update  ${REPO}/6/i386
