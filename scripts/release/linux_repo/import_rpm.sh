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

function fetch_rpm
{
    package=${1}
    version=${2}
    edition=${3}
    s3dir="${S3_PACKAGE_ROOT}/${edition}/rpm/${RPM_DIR}"
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
    # The variables EXISTS_ON_S3 and FOUND_FILE are (potentially) modified
    # in the fetch_rpm function to allow it to do the right thing when
    # acquiring a given RPM, based on whether it's already in S3 or not,
    # of if the file is not found at all.  This update is carried through
    # the rest of the for loop to ensure an RPM already on S3 isn't signed
    # again (which would change its checksum), or no copying or signing
    # attempt if the file doesn't exist.
    EXISTS_ON_S3=false
    FOUND_FILE=true
    RPM_DIR=${CENTOS}/x86_64
    rpm_filename=couchbase-server-${EDITION}-${VERSION}-centos${CENTOS}.x86_64.rpm
    fetch_rpm ${rpm_filename} ${VERSION} ${EDITION}

    if ${FOUND_FILE}; then
        cp ${rpm_filename} ${REPO}/${RPM_DIR}/

        if ! ${EXISTS_ON_S3}; then
            expect ./autosign_rpm.exp -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V4}" ${REPO}/${RPM_DIR}/${rpm_filename}
        fi
    fi
done

echo ""
echo "repo ready for signing: ${REPO}"
echo ""
