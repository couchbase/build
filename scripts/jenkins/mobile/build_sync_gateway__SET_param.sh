#!/bin/bash
#          
#   run by these jenkins jobs when successful:
#   
#   build_sync_gateway_master_centos-x86      |   build_sync_gateway_100_centos-x86
#   build_sync_gateway_master_centos-x64      |   build_sync_gateway_100_centos-x64
#   build_sync_gateway_master_macosx-x64      |   build_sync_gateway_100_macosx-x64
#   build_sync_gateway_master_ubuntu-x86      |   build_sync_gateway_100_ubuntu-x86
#   build_sync_gateway_master_ubuntu-x64      |   build_sync_gateway_100_ubuntu-x64
#   build_sync_gateway_master_win-2008-x86    |   build_sync_gateway_100_win-2008-x86
#   build_sync_gateway_master_win-2008-x64    |   build_sync_gateway_100_win-2008-x64
#   
#   with parameters
#  
#     SYNCGATE_VERSION_PARAM equal to one of:
#   
#           SYNCGATE_VERSION_CENTOS_X86
#           SYNCGATE_VERSION_CENTOS_X64
#           SYNCGATE_VERSION_MACOSX_X64
#           SYNCGATE_VERSION_UBUNTU_X86
#           SYNCGATE_VERSION_UBUNTU_X64
#           SYNCGATE_VERSION_WIN2008_X86
#           SYNCGATE_VERSION_WIN2008_X64
#           SYNCGATE_VERSION_WIN2012_X64
#   
#     REVISION  equal to a build number of the form n.n-mmmm
#     RELEASE   master, or 100 (for example)
#     EDITION   "community" or "enterprise"
# 
#   and will set the default value of the SYNCGATE_VERSION parameter in jobs
#   
#      build_cblite_android_master            |  build_cblite_android_100
#      mobile_functional_tests_android_master |  mobile_functional_tests_android_100
#          
source ~/.bash_profile
set -e

function usage
    {
    echo -e "\nuse:  ${0}   SYNCGATE-version-param  revision  branch\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
PARNAME=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
VERSION=${2}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
RELEASE=${3}

if [[ ! ${4} ]] ; then usage ; exit 66 ; fi
EDITION=${4}
EDN_PRFX=`echo ${EDITION} | tr '[a-z]' '[A-Z]'`

export RELEASE ; export VERSION ; export PARNAME

env | grep -iv password | grep -iv passwd | sort -u
echo ============================================== `date`

if [[ ${PARNAME} == SYNCGATE_VERSION_UBUNTU_X64 ]]
    then
    echo ${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl -j build_cblite_android_${RELEASE}            -p ${EDN_PRFX}_SYNCGATE_VERSION -v ${REVISION}
         ${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl -j build_cblite_android_${RELEASE}            -p ${EDN_PRFX}_SYNCGATE_VERSION -v ${REVISION}
fi
if [[ ${PARNAME} == SYNCGATE_VERSION_CENTOS_X64 ]]
    then
    echo ${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl -j mobile_functional_tests_android_${RELEASE} -p ${EDN_PRFX}_SYNCGATE_VERSION -v ${REVISION}
         ${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl -j mobile_functional_tests_android_${RELEASE} -p ${EDN_PRFX}_SYNCGATE_VERSION -v ${REVISION}
fi
if [[ ${PARNAME} == SYNCGATE_VERSION_MACOSX_X64 ]]
    then
    echo ${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl -j mobile_functional_tests_ios_${RELEASE}     -p ${EDN_PRFX}_SYNCGATE_VERSION -v ${REVISION}
         ${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl -j mobile_functional_tests_ios_${RELEASE}     -p ${EDN_PRFX}_SYNCGATE_VERSION -v ${REVISION}
fi

