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

function usage
    {
    echo ""
    echo "use:  `basename $0`  Release Edition"
    echo ""
    echo "      Release is build number, like 2.0.2-1234"
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
    }

function fetch_rpm
    {
    package=${1}
    latestbuilds="http://builds.hq.northscale.net/latestbuilds"
    if [[ ! -e ${package} ]] ; then echo "fetching ${package}" ; wget ${latestbuilds}/${package} ; else echo "alread have ${package}" ; fi
    }

function get_version_base
    {
    local __result_rel_num=$1
    local __result_bld_num=$2
    
    local versionarg=$3
    local rel_num
    local bld_num
    
    vrs_rex='([0-9]\.[0-9]\.[0-9])-([0-9]{1,})'
    
    if [[ $versionarg =~ $vrs_rex ]]
      then
        for N in 1 2 ; do
            if [[ $N -eq 1 ]] ; then rel_num=${BASH_REMATCH[$N]} ; fi
            if [[ $N -eq 2 ]] ; then bld_num=${BASH_REMATCH[$N]} ; fi
        done
      else
        echo ""
        echo 'bad version >>>'${versionarg}'<<<'
        usage
        exit
    fi
    
    eval $__result_rel_num="'$rel_num'"
    eval $__result_bld_num="'$bld_num'"
    }

VERSION=$1 ; shift ; if [[ ! ${VERSION} ]] ; then read -p "Release: "  VERSION ; fi

get_version_base BASEVER BLDNUM ${VERSION}

echo BASEVER is $BASEVER
echo BLDNUM  is $BLDNUM

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi

REPO=${LOCAL_REPO_ROOT}/${EDITION}/rpm

echo ""
echo "Importing into local ${EDITION} repo at ${REPO}"
echo ""

fetch_rpm  couchbase-server-${EDITION}_x86_64_${VERSION}-rel.rpm
cp         couchbase-server-${EDITION}_x86_64_${VERSION}-rel.rpm  ${REPO}/5/i386/couchbase-server_${BASEVER}.x86_64.rpm
cp         couchbase-server-${EDITION}_x86_64_${VERSION}-rel.rpm  ${REPO}/6/i386/couchbase-server_${BASEVER}.x86_64.rpm
    
fetch_rpm  couchbase-server-${EDITION}_x86_${VERSION}-rel.rpm
cp         couchbase-server-${EDITION}_x86_${VERSION}-rel.rpm     ${REPO}/5/i386/couchbase-server_${BASEVER}.i386.rpm
cp         couchbase-server-${EDITION}_x86_${VERSION}-rel.rpm     ${REPO}/6/i386/couchbase-server_${BASEVER}.i386.rpm

echo ""
echo "updating ${REPO}"
echo ""

createrepo --update  ${REPO}/5/x86_64
createrepo --update  ${REPO}/6/x86_64

createrepo --update  ${REPO}/5/i386
createrepo --update  ${REPO}/6/i386

echo ""
echo "repo ready for signing: ${REPO}"
echo ""
