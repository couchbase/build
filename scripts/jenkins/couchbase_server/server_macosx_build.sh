#!/bin/bash
#          
#          run by jenkins jobs: 'server_macosx_build_master'
#                               'server_macosx_build_300'
#          
#          with job paramters used in this script:
#             
#             PARENT_BUILD_NUMBER   e.g. 3.0.0-1234
#             
#          and called with paramters:     voltron_branch   release  bld_num    edition        manifest     over-ride-manifest
#          
#            by server_macosx_build_master:       master   0.0.0    nnnn      community       current.xml  external-override-master.xml
#            by server_macosx_build_300:           3.0.0   3.0.0    mmmm      enterprise      current.xml  external-override-3.0.0.xml
#          
##############

source ~jenkins/.bash_profile
set -e

LOG_TAIL=-24


function usage
    {
    echo -e "\nuse:  ${0}   voltron_branch  release  build_number  edition  manifest  override-manifest\n\n"
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

if [[ ! ${5} ]] ; then usage ; exit 55 ; fi
MFSFILE=${5}

if [[ ! ${6} ]] ; then usage ; exit 44 ; fi
OVR_XML=${6}

LOG_DIR_NAME=${EDITION}_logs
LOG_DIR=${WORKSPACE}/${LOG_DIR_NAME}
if [[ -e ${LOG_DIR} ]] ; then rm -rf ${LOG_DIR} ; fi
mkdir -p ${LOG_DIR}

LATEST=http://latestbuilds.hq.couchbase.com/
GET_CMD="curl ${LATEST}"

PKGSTORE=s3://packages.northscale.com/latestbuilds/couchbase_server/${VERSION}/${REVISION}
PUT_CMD="s3cmd put -P"


WS_PARENT=/Users/jenkins/jenkins/workspace
GRM_DIR=${WS_PARENT}/grommit

AUT_DIR=${WORKSPACE}/app-under-test
if [[ -e ${AUT_DIR}  ]] ; then rm -rf ${AUT_DIR}  ; fi

SVR_DIR=${AUT_DIR}/couchbase-server
GRM_SYM=${SVR_DIR}/grommit
MFS_DIR=${SVR_DIR}/manifest

VLT_DIR=${SVR_DIR}/build
TLM_DIR=${VLT_DIR}/build

if [[ -e ${SVR_DIR} ]] ; then rm -rf ${SVR_DIR} ; fi
mkdir -p ${SVR_DIR}

CHANGES_LIST=CHANGES_couchbase-server-${REVISION}-rel.txt
EMITTED_MFST=couchbase-server-${REVISION}-rel-manifest.xml
BUILTPACKAGE=couchbase-server-${EDITION}_x86_64_${REVISION}-rel.zip

PREFIX_DIR=/opt/couchbase


echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ [  1 ]  add 0 to buildnumber and set git_describe property 
echo ============================================ [  2 ]  create new /opt/couchbase directory
sudo rm    -rf ${PREFIX_DIR}
sudo mkdir  -p ${PREFIX_DIR}
sudo chmod 777 ${PREFIX_DIR}

echo ============================================ [  3 ]  git pull voltron
cd ${SVR_DIR}
echo ============================================  sync voltron
echo ============================================  to ${GITSPEC}
if [[ ! -d ${VLT_DIR} ]] ; then git clone git://10.1.1.210/voltron.git ${VLT_DIR}; fi
pushd      ${VLT_DIR} 2>&1 > /dev/null
git checkout      ${GITSPEC}
git pull  origin  ${GITSPEC}
echo ============================================ [  4 ]  git submodule update --init
git submodule init
git submodule update
git show --stat
popd                  2>&1 > /dev/null

echo ============================================ [  5 ]  create grommit link
if [[ ! -e ${GRM_SYM} ]] ; then ln -s ${GRM_DIR} ${GRM_SYM} ; fi

echo ============================================ [  6 ]  manifest master fetch
if [[ ! -d ${MFS_DIR} ]] ; then git clone https://github.com/couchbase/manifest.git ${MFS_DIR}; fi
pushd      ${MFS_DIR} 2>&1 > /dev/null
git checkout      master
git pull  origin  master
git show --stat
popd                  2>&1 > /dev/null

echo ============================================ [  7 ]  get voltron latest change
pushd      ${VLT_DIR} 2>&1 > /dev/null
VOLTRON_SHA=`git log -1 | grep commit | awk '{print $2}' | head -1`
popd                  2>&1 > /dev/null

MFS_OUT=${VLT_DIR}/current.xml
GIT_CACHE=~/gitcache
BLANKFILE="''"

mkdir  -p  ${TLM_DIR}
pushd      ${TLM_DIR} 2>&1 > /dev/null

if [[ ${MFSFILE} == current.xml ]]
  then
    MFS_SRC=couchbase-server_${REVISION}.manifest.xml
    echo ============================================ [  8 ]  download
    ${GET_CMD}/${VERSION}/${REVISION}/${MFS_SRC} --output ${VLT_DIR}/${MFSFILE}
    
    echo ============================================ [  9 ]  manifest-fetch
    echo "********RUNNING: fetch-manifest.rb *******************"
    ( ${MFS_DIR}/fetch-manifest.rb              \
               ${VLT_DIR}/${MFSFILE}            \
               ${BLANKFILE}                     \
               ${SVR_DIR}/CHANGES.out           \
               ${MFS_OUT}                       \
               ${VOLTRON_SHA}                   \
               ${GIT_CACHE}                     \
                                        2>&1 )  >>  ${LOG_DIR}/00_fetch_manifest.log
  else
    cp ${MFS_DIR}/${MFSFILE}  ${VLT_DIR}
    
    echo ============================================ [  9 ]  manifest-fetch
    echo "********RUNNING: fetch-manifest.rb *******************"
    ( ${MFS_DIR}/fetch-manifest.rb              \
               ${MFS_DIR}/${MFSFILE}            \
               ${MFS_DIR}/${OVR_XML}            \
               ${SVR_DIR}/CHANGES.out           \
               ${MFS_OUT}                       \
               ${VOLTRON_SHA}                   \
               ${GIT_CACHE}                     \
                                        2>&1 )  >>  ${LOG_DIR}/00_fetch_manifest.log
fi
if  [[ -e ${LOG_DIR}/00_fetch_manifest.log ]]
    then
    echo
    echo "===================================== ${LOG_DIR}/00_fetch_manifest.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/00_fetch_manifest.log
fi
popd                  2>&1 > /dev/null


#  echo ============================================ [  9 ]  manifest-fetch
#  pushd      ${VLT_DIR} 2>&1 > /dev/null
#  repo init -u git://github.com/couchbase/manifest -m ${MFS_DIR}/${MFSFILE}
#  repo sync --jobs=4

echo ============================================ [ 10 ]  make clean : ${TLM_DIR}
pushd      ${TLM_DIR} 2>&1 > /dev/null
make clean-all
echo ============================================ [ 11 ]  clean couchdbx-app
cd         ${TLM_DIR}/couchdbx-app
git  clean -dfx
make clean
popd                  2>&1 > /dev/null

echo ============================================ [ 12 ]  rm dep-* packages 
pushd      ${SVR_DIR} 2>&1 > /dev/null
rm -rf dep-*.tar.gz
echo ============================================ [ 13 ]  rm -rf rpms and debs 
popd                  2>&1 > /dev/null

echo ============================================ [ 14 ]  couchbase-server make enterprise 
pushd      ${VLT_DIR} 2>&1 > /dev/null
echo "********RUNNING: make package-mac  *******************"
( PRODUCT_VERSION=${REVISION}-rel           \
           PATH=/opt/couchbase/bin:$PATH    \
           make                             \
           COUCH_EXTRA=                     \
           PRODUCT=couchbase-server         \
           PRODUCT_BASE=couchbase           \
           PRODUCT_KIND=server              \
           PREFIX=/opt/couchbase            \
           MANIFEST_XML=${MFSFILE}          \
           OVERRIDE_XML=${OVR_XML}          \
           LICENSE=LICENSE-${EDITION}.txt   \
           package-mac                      \
           PRODUCT_VERSION=${REVISION}-rel  \
           OPENSSL=0.9.8                    \
           USER=buildbot                    \
                                    2>&1 )  >>  ${LOG_DIR}/01_make_package_mac.log

if  [[ -e ${LOG_DIR}/01_make_package_mac.log ]]
    then
    echo
    echo "===================================== ${LOG_DIR}/01_make_package_mac.log"
    echo ". . ."
    tail ${LOG_TAIL}                            ${LOG_DIR}/01_make_package_mac.log
fi
popd                  2>&1 > /dev/null
echo ============================================


pushd      ${TLM_DIR} 2>&1 > /dev/null
echo ============================================ [ 15 ]  move zip files
cp couchdbx-app/build/Release/*.zip couchbase-server.zip
echo ============================================ [ 16 ]  rename the installation package
mv  couchbase-server.zip  ${WORKSPACE}/${BUILTPACKAGE}
popd                  2>&1 > /dev/null

pushd      ${SVR_DIR} 2>&1 > /dev/null
echo ============================================ [ 17 ]  rename changes.out
cp  CHANGES.out           ${WORKSPACE}/${CHANGES_LIST}

echo ============================================ [ 18 ]  rename build/current.xml to ${EMITTED_MFST}
cp  ${MFS_OUT}            ${WORKSPACE}/${EMITTED_MFST}
popd                  2>&1 > /dev/null

echo ============================================ [ 19 ]  upload ${BUILTPACKAGE} file to buildbot master
echo ============================================ [ 20 ]  upload ${CHANGES_LIST} file to buildbot master
echo ============================================ [ 21 ]  upload ${EMITTED_MFST} file to buildbot master

echo ============================================ [ 22 ]  upload-build-to-cbfs
${PUT_CMD}                ${WORKSPACE}/${BUILTPACKAGE} ${PKGSTORE}/${BUILTPACKAGE}
${PUT_CMD}                ${WORKSPACE}/${CHANGES_LIST} ${PKGSTORE}/${CHANGES_LIST}
${PUT_CMD}                ${WORKSPACE}/${EMITTED_MFST} ${PKGSTORE}/${EMITTED_MFST}

echo ============================================ [ 23 ]  create new /opt/couchbase
echo ============================================ [ 24 ]  couchbase-server make community
echo ============================================ [ 25 ]  move zip files_1
echo ============================================ [ 26 ]  rename the installation package_1
echo ============================================ [ 27 ]  rename changes.out_1
echo ============================================ [ 28 ]  rename build/current.xml to PRODUCT_VERSION-manifest.xml_1
echo ============================================ [ 29 ]  upload package to buildbot master_1
echo ============================================ [ 30 ]  upload changes file to buildbot master_1
echo ============================================ [ 31 ]  upload manifest file to buildbot master_1
echo ============================================ [ 32 ]  upload-build-to-cbfs_1

echo ============================================ [ 33 ]  upload the installation package to s3
echo ============================================ [ 34 ]  pkg_index


############## EXIT function finish
