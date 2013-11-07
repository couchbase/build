#!/bin/bash
#          
#          run by jenkins job 'changelog-report-current-build'
#          
#          with paramters:  
#               
#               BUILDER      -- e.g. ubuntu-1204-x86-master-builder
#               
#               BRANCH       -- 
#               
#               CURRENT_BLD  -- 
#               
set -e
env | grep -v password | grep -v passwd | sort
echo =========================================
echo ____________starting___`date`

REPORT_DIR=${WORKSPACE}/${BUILDER}
if [[ ! -d ${REPORT_DIR} ]] ; then mkdir ${REPORT_DIR} ; fi

PROPFILE=${REPORT_DIR}/last_good.properties
echo see ${PROPFILE}

${WORKSPACE}/build/scripts/cgi/get_latest_good_build.pl -b ${BUILDER} -r ${BRANCH} > ${PROPFILE}
sudo chmod 666 ${PROPFILE}
ls -l ${PROPFILE}
cat   ${PROPFILE}
echo =========================================

export FIRST_BLD=`grep BUILD_NUMBER ${PROPFILE} | awk -F- '{print $2}'`

export LAST_BLD=${REPORT_DIR}/current.xml

if [[ ! -f ${LAST_BLD} ]]
    then
    echo ""
    echo "ERROR: Failed to locate current manifest:"
    echo ""
    echo "    ${LAST_BLD}"
    echo ""
    echo "Verify that buildbot uploaded this file."
    echo ""
    exit 99
fi

echo "----------------- showing changes from ${FIRST_BLD} to ${LAST_BLD}"

DO_SENDIT=0
PFORM_ARG=""
PFORM_REX='([a-z]*-[a-z0-9]*)-[a-z0-9]*-builder'
PFORM_REX='(ubuntu-x64)-[a-z0-9]*-builder'

if [[ ${BUILDER} =~ ${PFORM_REX} ]]
    then
    PLATFORM=${BASH_REMATCH[1]}
    PFORM_ARG="-P ${PLATFORM}"
    echo "----------------- builder ${BUILDER} is on platform ${PFORM_ARG} -----------------"
    DO_SENDIT=1
fi

BLDNUM_ARG=""
if [[ ${CURRENT_BLD} ]] ; then BLDNUM_ARG="-b ${CURRENT_BLD}" ; fi

${WORKSPACE}/build/scripts/jenkins/changelog-report.sh -d ${REPORT_DIR} -e ${DO_SENDIT}  ${BLDNUM_ARG}  ${PFORM_ARG}

