#!/bin/bash
#
# run by jenkins job:  'smoke-test-4nodes-centos64'
#                      'smoke-test-4nodes-ubuntu64'
#                       etc.
# 
#
source ~/.bash_profile
set -e
ulimit -a

function usage
    {
    echo -e "\nuse:  ${0}   platform  build_number\n\nwhere\n"
    echo -e "   platform      is one of:       centos-6-64, ubuntu-6-64, ...\n"
    echo -e "   build_number  is of the form:  3.0.0-920\n\n"
    }

if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
OS_ARCH=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
VERSION=${2}

CONFIG_SRC=$(pwd)

AUT_DIR=${WORKSPACE}/testrunner
CONFIG_DEST=${AUT_DIR}/b/resources/

if [[ $OS_ARCH =~ centos-6-64 ]] ; then CONFIG=${OS_ARCH}.ini ; fi
if [[ $OS_ARCH =~ centos-6-86 ]] ; then CONFIG=${OS_ARCH}.ini ; fi
if [[ $OS_ARCH =~ ubuntu-6-64 ]] ; then CONFIG=${OS_ARCH}.ini ; fi
if [[ $OS_ARCH =~ ubuntu-6-86 ]] ; then CONFIG=${OS_ARCH}.ini ; fi

if [[ !                  ${CONFIG} ]] ; then echo -e "\n\nUnsupported platform: ${OS_ARCH}\n"               ; usage ; exit 1 ; fi
if [[ ! -e ${CONFIG_SRC}/${CONFIG} ]] ; then echo -e "\n\nMissing config file:  ${CONFIG_SRC}/${CONFIG}\n"  ; usage ; exit 2 ; fi


echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ sync up testrunner
if [[ ! -d ${AUT_DIR} ]] ; then git clone https://github.com/couchbase/testrunner.git ${AUT_DIR}; fi
cd         ${AUT_DIR}
git checkout      master
git pull  origin  master
git show --stat

cp ${CONFIG_SRC}/${CONFIG}  ${CONFIG_DEST}

python ${AUT_DIR}/scripts/install.py -i ${CONFIG_DEST}/${CONFIG} -p version=${VERSION},product=cb,parallel=True,vbuckets=16

python ${AUT_DIR}/testrunner         -i ${CONFIG_DEST}/${CONFIG} -c conf/simple.conf


