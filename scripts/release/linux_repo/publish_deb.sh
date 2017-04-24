#!/bin/bash
#
#  Publish release packages into local Debian repo.  Step 4 of 6:
#
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import packages
#   4.  publish packages to local repo
#   5.  upload to shared repository
#   6.  upload keys and sources files
#
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi

function usage
{
    echo ""
    echo "use:  `basename $0`  Edition"
    echo ""
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
}

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[ ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi

declare -A DISTROS=( [precise]="ubuntu12.04" [trusty]="ubuntu14.04" [xenial]="ubuntu16.04" [wheezy]="debian7" [jessie]="debian8" )

REPO=${LOCAL_REPO_ROOT}/${EDITION}/deb
PUB_REPO=${REPO}/public

echo ""
echo "publishing into local ${EDITION} repo at ${PUB_REPO}"
echo ""

for distro in "${!DISTROS[@]}"
do
    aptly publish repo -component="${distro}/main" -distribution="${distro}" ${distro}
done

echo ""
echo "moving published repo into local repo area at ${REPO}"
echo ""

# Clear out top-level directory and move directories in 'publish'
# up one level
rm -rf ${REPO}/conf ${REPO}/db ${REPO}/pool
mv ${PUB_REPO}/dists ${REPO}/
mv ${PUB_REPO}/pool ${REPO}/
rmdir ${PUB_REPO}

echo ""
echo "published local repo ready at ${PUB_REPO}"
echo ""
