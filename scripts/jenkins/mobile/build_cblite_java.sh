#!/bin/bash
#          
#          run by jenkins jobs: 'build_cblite_java_master'
#                               'build_cblite_java_101'
#          
#          with job paramters used in this script:
#             
#             SYNCGATE_VERSION  ( hard-coded to run on ubuntu-x64 )
#                                 now of the form n.n-mmmm
#             
#          and called with paramters:         branch_name  release_number  build_number  edition
#          
#            by build_cblite_java_master:     master           0.0.0       1234      community
#            by build_cblite_java_101:        release/1.0.1    1.0.1       1234      enterprise
#          
#          in an environment with these variables set:
#          
#            MAVEN_UPLOAD_USERNAME
#            MAVEN_UPLOAD_PASSWORD
#            
##############

source ~jenkins/.bash_profile
export DISPLAY=:0
set -e

LOG_TAIL=-24


function usage
    {
    echo -e "\nuse:  ${0}   branch_name  release_number  build_number  edition (community or enterprise)\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
VERSION=${2}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
BLD_NUM=${3}
REVISION=${VERSION}-${BLD_NUM}

if [[ ! ${4} ]] ; then usage ; exit 66 ; fi
EDITION=${4}

LOG_DIR_NAME=${EDITION}_logs
LOG_DIR=${WORKSPACE}/${LOG_DIR_NAME}
if [[ -e ${LOG_DIR} ]] ; then rm -rf ${LOG_DIR} ; fi
mkdir -p ${LOG_DIR}

PKGSTORE=s3://packages.couchbase.com/builds/mobile/java/${VERSION}/${REVISION}
PUT_CMD="s3cmd put -P"

export MAVEN_UPLOAD_VERSION=${REVISION}
export MAVEN_UPLOAD_REPO_URL=http://files.couchbase.com/maven2/


AUT_DIR=${WORKSPACE}/app-under-test
if [[ -e ${AUT_DIR}  ]] ; then rm -rf ${AUT_DIR}  ; fi

JAVA_DIR=${AUT_DIR}/java
if [[ -e ${JAVA_DIR} ]] ; then rm -rf ${JAVA_DIR} ; fi
mkdir -p ${JAVA_DIR}

export MAVEN_LOCAL_REPO=${JAVA_DIR}/release/m2

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

cd ${JAVA_DIR}
echo ============================================  sync couchbase-lite-java
echo ============================================  to ${GITSPEC}

if [[ ! -d couchbase-lite-java ]] ; then git clone https://github.com/couchbase/couchbase-lite-java.git ; fi
cd         couchbase-lite-java
git checkout      ${GITSPEC}
git pull  origin  ${GITSPEC}
git submodule init
git submodule update
git show --stat


echo ============================================  build java
cd ${JAVA_DIR}

echo "********RUNNING: release/build_artifacts.sh ********************"
( release/build_artifacts.sh 2>&1 )          >> ${LOG_DIR}/00_java_build.log

if  [[ -e ${LOG_DIR}/00_java_build.log ]]
    then
    echo
    echo "===================================== ${LOG_DIR}/00_java_build.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/00_java_build.log
fi

exit 0

echo "********NOT RUNNING: release/upload_artifacts.sh *******************"
#( ./upload_artifacts.sh 2>&1 )               >> ${LOG_DIR}/02_upload_android_artifacts.log
# 
# if  [[ -e ${LOG_DIR}/02_upload_android_artifacts.log ]]
#     then
#     echo
#     echo "===================================== ${LOG_DIR}/02_upload_android_artifacts.log"
#     echo ". . ."
#     tail ${LOG_TAIL}                            ${LOG_DIR}/02_upload_android_artifacts.log
# fi

echo ============================================  build java zipfile

if [[ ! -d ${MAVEN_LOCAL_REPO} ]] ; then mkdir -p ${MAVEN_LOCAL_REPO} ; fi

cd ${JAVA_DIR}/release
cp ${WORKSPACE}/build/license/couchbase-lite/LICENSE_${EDITION}.txt  LICENSE.txt

MVN_ZIP=couchbase-lite-${REVISION}-java.zip
JAV_ZIP=couchbase-lite-java-${EDITION}_${REVISION}.zip

rm -f                                           ${LOG_DIR}/03_android_package.log
    ${JAVA_DIR}/release/zip_jars.sh ${REVISION} ${LOG_DIR}/03_android_package.log

if  [[ -e ${LOG_DIR}/03_android_package.log ]]
    then
    echo "===================================== ${LOG_DIR}/03_android_package.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/03_android_package.log
fi

echo ============================================ upload ${PKGSTORE}/${JAV_ZIP}
echo  ${JAVA_DIR}/release/target/${MVN_ZIP}
file  ${JAVA_DIR}/release/target/${MVN_ZIP}  || exit 99
cp    ${JAVA_DIR}/release/target/${MVN_ZIP}             ${WORKSPACE}/${JAV_ZIP}
echo        ${WORKSPACE}/${JAV_ZIP}
${PUT_CMD}  ${WORKSPACE}/${JAV_ZIP}                      ${PKGSTORE}/${JAV_ZIP}




############## EXIT function finish
