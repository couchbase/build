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
    rel_name=${2}
    latestbuilds="http://172.23.120.24/builds/latestbuilds/couchbase-server/${rel_name}"
    if [[ ! -e ${package} ]] ; then echo "fetching ${package}" ; wget ${latestbuilds}/${package} ; else echo "alread have ${package}" ; fi
}

function get_version_base
{
    local __result_rel_num=$1
    local __result_bld_num=$2
    local __result_release=$3

    local versionarg=$4
    local rel_num
    local bld_num
    local rel_name

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

    if [[ $rel_num == 4.0* || $rel_num == 4.1* ]]; then
        rel_name=sherlock
    elif [[ $rel_num == 4.5* || $rel_num == 4.6* ]]; then
        rel_name=watson
    fi

    eval $__result_rel_num="'$rel_num'"
    eval $__result_bld_num="'$bld_num'"
    eval $__result_release="'$rel_name'"
}

VER_REX='[0-9]\.[0-9]\.[0-9]-[0-9]{1,}'

VERSION=$1 ; shift ; if [[ ! ${VERSION} ]] ; then read -p "Release: "  VERSION ; fi

get_version_base BASEVER BLDNUM RELEASE ${VERSION}

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi

REPO=${LOCAL_REPO_ROOT}/${EDITION}/deb

echo "Importing into local ${EDITION} repo at ${REPO}"

fetch_deb ${BLDNUM}/couchbase-server-${EDITION}_${VERSION}-ubuntu12.04_amd64.deb $RELEASE
reprepro -T deb -V --ignore=wrongdistribution --basedir ${REPO}  includedeb  precise couchbase-server-${EDITION}_${VERSION}-ubuntu12.04_amd64.deb

fetch_deb ${BLDNUM}/couchbase-server-${EDITION}_${VERSION}-ubuntu14.04_amd64.deb $RELEASE
reprepro -T deb -V --ignore=wrongdistribution --basedir ${REPO}  includedeb  trusty  couchbase-server-${EDITION}_${VERSION}-ubuntu14.04_amd64.deb

fetch_deb ${BLDNUM}/couchbase-server-${EDITION}_${VERSION}-debian7_amd64.deb $RELEASE
reprepro -T deb -V --ignore=wrongdistribution --basedir ${REPO}  includedeb  wheezy  couchbase-server-${EDITION}_${VERSION}-debian7_amd64.deb

fetch_deb ${BLDNUM}/couchbase-server-${EDITION}_${VERSION}-debian8_amd64.deb $RELEASE
reprepro -T deb -V --ignore=wrongdistribution --basedir ${REPO}  includedeb  jessie couchbase-server-${EDITION}_${VERSION}-debian8_amd64.deb

echo ""
echo "local repo ready at ${REPO}"
echo ""
