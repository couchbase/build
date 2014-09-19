#!/bin/bash
#  
#  Import release packages into local debian repo.  Step 3 of five:
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
    echo "use:  `basename $0`  Release Edition"
    echo ""
    echo "      Release is build number, like 2.0.2-1234"
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
    echo "This script expects the couchbase-server .deb files to exist in the current directory."
    echo ""
    echo "Note:  the 'reprepro' executable will rename the files when they are imported."
    echo ""
    echo ""
    }

function fetch_deb
    {
    package=${1}
    latestbuilds="http://builds.hq.northscale.net/latestbuilds"
    if [[ ! -e ${package} ]] ; then echo "fetching ${package}" ; wget ${latestbuilds}/${package} ; else echo "alread have ${package}" ; fi
    }

VER_REX='[0-9]\.[0-9]\.[0-9]-[0-9]{1,}'

VERSION=$1 ; shift ; if [[ ! ${VERSION} ]] ; then read -p "Release: "  VERSION ; fi
if [[ ! ${VERSION} =~ ${VER_REX} ]]                                ; then echo "bad version" ; usage ; exit 9 ; fi

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi

REPO=${LOCAL_REPO_ROOT}/${EDITION}/deb

echo "Importing into local ${EDITION} repo at ${REPO}"

fetch_deb                                                                            couchbase-server-${EDITION}_x86_64_${VERSION}-rel.deb
reprepro -T deb -V --ignore=wrongdistribution --basedir ${REPO}  includedeb  precise couchbase-server-${EDITION}_x86_64_${VERSION}-rel.deb
reprepro -T deb -V --ignore=wrongdistribution --basedir ${REPO}  includedeb  lucid   couchbase-server-${EDITION}_x86_64_${VERSION}-rel.deb

echo ""
echo "local repo ready at ${REPO}"
echo ""
