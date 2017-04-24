#!/bin/bash
#
#  Import release packages into local Debian repo.  Step 3 of 6:
#
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import packages
#   4.  publish packages to local repo
#   5.  upload to shared repository
#   6.  upload keys and sources files
#
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi
if [[ ! ${S3_PACKAGE_ROOT} ]] ; then  S3_PACKAGE_ROOT=s3://packages.couchbase.com/releases/couchbase-server ; fi

function usage
{
    echo ""
    echo "use:  `basename $0`  Release Edition"
    echo ""
    echo "      Release is version, like 4.6.0"
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
}

function write_config
{
    edition=${1}

    sed -e "s#\${HOME}#${HOME}#" -e "s/\${edition}/${edition}/" ./couchbase-release/aptly.conf > ${HOME}/.aptly.conf
}

function fetch_deb
{
    package=${1}
    version=${2}
    edition=${3}
    s3dir="${S3_PACKAGE_ROOT}/${edition}/deb/${DEB_DIR}"
    releases="http://172.23.120.24/builds/releases/${version}"

    if [[ "${edition}" = "community" ]]
    then
        releases="${releases}/ce"
    fi

    if [[ -n $(s3cmd ls ${s3dir}/${package}) ]]
    then
        EXISTS_ON_S3=true
    fi

    if [[ ! -e ${package} ]]
    then
        echo "fetching ${package}"
        if ${EXISTS_ON_S3}
        then
            s3cmd get ${s3dir}/${package}
            if [[ $? != 0 ]]
            then
                echo "unable to fetch ${package} from S3"
                FOUND_FILE=false
            fi
        else
            wget ${releases}/${package}
            if [[ $? != 0 ]]
            then
                echo "unable to fetch ${package} from releases"
                FOUND_FILE=false
            fi
        fi
    else
        echo "already have ${package}"
    fi
}

VER_REX='[0-9]\.[0-9]\.[0-9]-[0-9]{1,}'

VERSION=$1 ; shift ; if [[ ! ${VERSION} ]] ; then read -p "Release: "  VERSION ; fi
EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[ ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi

declare -A DISTROS=( [precise]="ubuntu12.04" [trusty]="ubuntu14.04" [xenial]="ubuntu16.04" [wheezy]="debian7" [jessie]="debian8" )

REPO=${LOCAL_REPO_ROOT}/${EDITION}/deb

echo ""
echo "Importing into local ${EDITION} repo at ${REPO}"
echo ""

write_config ${EDITION}

for distro in "${!DISTROS[@]}"
do
    # The variables EXISTS_ON_S3 and FOUND_FILE are (potentially) modified
    # in the fetch_deb function to allow it to do the right thing when
    # acquiring a given deb, based on whether it's already in S3 or not,
    # or if the file is not found at all. This update is carried through
    # the rest of the for loop to ensure a deb is not attempted to be added
    # to the repo if the file doesn't exist.
    EXISTS_ON_S3=false
    FOUND_FILE=true
    DEB_DIR="pool/${distro}/main/c/couchbase-server"
    deb_filename=couchbase-server-${EDITION}_${VERSION}-${DISTROS[$distro]}_amd64.deb
    fetch_deb ${deb_filename} ${VERSION} ${EDITION}

    if ${FOUND_FILE}; then
        aptly repo add ${distro} ${deb_filename}
    fi
done

echo ""
echo "local repo ready at ${REPO}"
echo ""
