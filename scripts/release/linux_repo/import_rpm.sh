#!/bin/bash
#
#  Create a new local yum repo.  Step 3 of six:
#
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import and sign packages
#   4.  sign local repo
#   5.  upload local repo to shared repository
#   6.  upload keys and yum.repos.d
#
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi

function usage
{
    echo ""
    echo "use:  `basename $0`  Release Edition"
    echo ""
    echo "      Release is version, like 4.6.0"
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
}

function fetch_rpm
{
    package=${1}
    version=${2}
    edition=${3}
    releases="http://172.23.120.24/builds/releases/${version}"
    if [[ "${edition}" = "community" ]]
    then
        releases="${releases}/ce"
    fi
    if [[ ! -e ${package} ]]
    then
        echo "fetching ${package}"
        wget ${releases}/${package}
    else
        echo "already have ${package}"
    fi
}

VERSION=$1 ; shift ; if [[ ! ${VERSION} ]] ; then read -p "Release: "  VERSION ; fi
EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[ ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi

REPO=${LOCAL_REPO_ROOT}/${EDITION}/rpm

echo ""
echo "Importing into local ${EDITION} repo at ${REPO}"
echo ""

RPM_GPG_KEY_V4=CD406E62

for CENTOS in 6 7
do
    rpm_filename=couchbase-server-${EDITION}-${VERSION}-centos${CENTOS}.x86_64.rpm
    fetch_rpm ${rpm_filename} ${VERSION} ${EDITION}
    cp ${rpm_filename} ${REPO}/${CENTOS}/x86_64/
    expect ./autosign_rpm.exp -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V4}" ${REPO}/${CENTOS}/x86_64/${rpm_filename}
done

echo ""
echo "repo ready for signing: ${REPO}"
echo ""
