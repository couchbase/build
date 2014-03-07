#!/bin/bash
#
# run by jenkins job 'postbuild-validation'
# 
# 
#

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ sync up testrunner, build

if [[ ! -d build ]] ; then git clone https://github.com/couchbase/build.git ; fi

echo "The current working directory $(pwd)"

if [[ ! -d testrunner ]] ; then git clone https://github.com/couchbase/testrunner.git ; fi

echo "The current working directory $(pwd)."

if [ "$1" = "--centos64" ]
    then
       configini="centos-6-x86.ini"
fi

cp ./build/scripts/jenkins/system_test/postbuild-validation/${configini} ./testrunner/b/resources

pushd testrunner  2>&1 > /dev/null


python ./scripts/install.py -i ./b/resources/${configini} -p version=3.0.0-398,product=cb,parallel=True,vbuckets=16

echo "The current working directory $(pwd) "
python testrunner -i b/resources/${configini} -c conf/simple.conf


