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

VERSION=$1 ; shift ; if [[ ! ${VERSION} ]] ; then read -p "Release: "  VERSION ; fi

get_version_base BASEVER BLDNUM RELEASE ${VERSION}


EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi

REPO=${LOCAL_REPO_ROOT}/${EDITION}/rpm

echo ""
echo "Importing into local ${EDITION} repo at ${REPO}"
echo ""

for CENTOS in 6 7
do
    fetch_rpm  ${BLDNUM}/couchbase-server-${EDITION}-${VERSION}-centos${CENTOS}.x86_64.rpm $RELEASE
    cp couchbase-server-${EDITION}-${VERSION}-centos${CENTOS}.x86_64.rpm  ${REPO}/${CENTOS}/x86_64/couchbase-server-${EDITION}-${BASEVER}-centos${CENTOS}.x86_64.rpm
done

echo ""
echo "updating ${REPO}"
echo ""

for CENTOS in 6 7
do
    createrepo --simple-md-filenames --update  ${REPO}/${CENTOS}/x86_64
done

echo ""
echo "repo ready for signing: ${REPO}"
echo ""
