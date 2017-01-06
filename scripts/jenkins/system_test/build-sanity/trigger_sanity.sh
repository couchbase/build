#!/bin/bash
#
# This script finds if there is a new build to run build-sanity against
# The goal is to make this script version/release number agnostic
#

BASEDIR=$(cd $(dirname $BASH_SOURCE) && pwd)

function show_help {
    echo "Usage: ./trigger_sanity.sh <options>"
    echo "Options:"
    echo "   -v :  version number (4.0.0, 4.0.1, etc)"
}

while getopts :v:h ARG; do
    case $ARG in
        v) VERSION_NUM="$OPTARG"
           ;;

        h) show_help
           ;;

        \?) #unrecognized option - show help
            echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
            show_help
    esac
done

if [ "x$VERSION_NUM" = "x" ]; then
    echo "Version number is required"
    exit 1
fi

rm -f *-manifest.xml
rm -f current_build_number
rm -f changelog-*
rm -f committers_email
rm -f env_prop_file

if [ ! -z $FORCE_BUILD_NUMBER ]; then
    if python ${BASEDIR}/last_good_build.py -v $VERSION_NUM -n $FORCE_BUILD_NUMBER; then
        build_number=$FORCE_BUILD_NUMBER
    fi
fi

if [ -z $build_number ]; then
    build_number=`python ${BASEDIR}/last_good_build.py -v $VERSION_NUM`
    if [ "${build_number}" == "0" ]; then
        echo "Couldn't retrieve latest build information"
        exit 1
    fi
fi

REL_CODE="sherlock"
if [[ $VERSION_NUM = 4.5* || $VERSION_NUM = 4.6* ]]; then
    REL_CODE="watson"
elif [[ $VERSION_NUM = 4.7* || $VERSION_NUM = 5.0* ]]; then
    REL_CODE="spock"
fi

last_completed_build_num="1"
if [ -f previous_completed_build/current_build_number ]; then
    last_completed_build_num=`cat previous_completed_build/current_build_number`
fi

if [ "${build_number}" == "${last_completed_build_num}" ]; then
    echo "No new build since last build-sanity run"
else

    echo ${build_number} > current_build_number

    # create changelog
    cur_manifest="couchbase-server-${VERSION_NUM}-${build_number}-manifest.xml"
    prev_manifest="couchbase-server-${VERSION_NUM}-${last_completed_build_num}-manifest.xml"

    wget http://172.23.120.24/builds/latestbuilds/couchbase-server/${REL_CODE}/${build_number}/${cur_manifest}
    wget http://172.23.120.24/builds/latestbuilds/couchbase-server/${REL_CODE}/${last_completed_build_num}/${prev_manifest}

    if [ -f ${cur_manifest} -a -f ${prev_manifest} ]; then
        change_log_file="changelog-${last_completed_build_num}-${build_number}.txt"
        python ${BASEDIR}/manifest_diff.py -o ${prev_manifest} -n ${cur_manifest} -e > ${change_log_file}
        cp ${change_log_file} changelog.txt
    fi

    echo "CURRENT_BUILD_NUMBER=${build_number}" | tee env_prop_file
    echo "CURRENT_VERSION=${VERSION_NUM}" >> env_prop_file
    echo "COMMITTERS_EMAIL=`cat committers_email`" >> env_prop_file
fi
