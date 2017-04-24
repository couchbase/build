#!/bin/bash
#
#  Create a new local Debian repo.  Step 2 of 6:
#
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import packages
#   4.  publish packages to local repo
#   5.  upload to shared repository
#   6.  upload keys and sources files
#
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[ ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi

if [[ ${EDITION} == 'community'  ]] ; then EDITION_NAME='Community Edition'  ; fi
if [[ ${EDITION} == 'enterprise' ]] ; then EDITION_NAME='Enterprise Edition' ; fi


REPO=${LOCAL_REPO_ROOT}/${EDITION}/deb

echo ""
echo "Creating local ${EDITION} deb repo at ${REPO}"
echo ""

KEY=D9223EDA
declare -A DISTROS=( [precise]="12.04" [trusty]="14.04" [xenial]="16.04" [wheezy]="7.0" [jessie]="8.0" )

mkdir -p ${REPO}/conf

OUTFILE=${REPO}/conf/distributions

echo "writing ${OUTFILE}"

echo "# `date`"                                                      > ${OUTFILE}

for distro in "${!DISTROS[@]}"
do
    echo ""                                                         >> ${OUTFILE}
    echo "Origin: couchbase"                                        >> ${OUTFILE}
    echo "SignWith: ${KEY}"                                         >> ${OUTFILE}
    echo "Suite: ${distro}"                                         >> ${OUTFILE}
    echo "Codename: ${distro}"                                      >> ${OUTFILE}
    echo "Version: ${DISTROS[$distro]}"                             >> ${OUTFILE}
    echo "Components: ${distro}/main"                               >> ${OUTFILE}
    echo "Architectures: amd64 source"                              >> ${OUTFILE}
    echo "Description: Couchbase ${EDITION_NAME} Repository"        >> ${OUTFILE}

    aptly repo create -component="${distro}/main" -distribution="${distro}" ${distro}
done

echo ""
echo "Deb repo ready for import: ${LOCAL_REPO_ROOT}"
echo ""
