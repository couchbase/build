#!/bin/bash
#          
#          run by jenkins jobs 'build_cblite_ios_master', 'build_cblite_ios_stable'
#          
#          with paramters:  branch_name  release number
#          
#                 e.g.:     master         0.0
#                 e.g.:     stable         1.0
#          
source ~jenkins/.bash_profile
set -e

LOG_TAIL=-24


function usage
    {
    echo -e "\nuse:  ${0}   branch_name  release_number\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
VERSION=${2}
REVISION=${VERSION}-${BUILD_NUMBER}

LOG_FILE=${WORKSPACE}/build_ios_results.log
if [[ -e ${LOG_FILE} ]] ; then rm -f ${LOG_FILE} ; fi

ZIP_FILE=cblite_ios_${REVISION}.zip

BASE_DIR=${WORKSPACE}/couchbase-lite-ios
BUILDDIR=${BASE_DIR}/build

ZIP_PATH=${BASE_DIR}/${ZIP_FILE}
ZIP_SRCD=${BASE_DIR}/zipfile_staging

README_D=${BASE_DIR}
README_F=${README_D}/README.md
RME_DEST=${ZIP_SRCD}

LICENSED=${BASE_DIR}/release
LICENSEF=${LICENSED}/LICENSE.txt
LIC_DEST=${ZIP_SRCD}

RIO_SRCD=${BUILDDIR}/Release-ios-universal
RIO_DEST=${ZIP_SRCD}

REL_SRCD=${BUILDDIR}/Release
REL_DEST=${ZIP_SRCD}

LSA_SRCD=${BUILDDIR}/Release
LSA_DEST=${ZIP_SRCD}

LIB_SRCD=${BUILDDIR}/Release-CBLJSViewCompiler-ios-universal
LIB_SRCF=${LIB_SRCD}/libCBLJSViewCompiler.a
LIB_DEST=${ZIP_SRCD}/Extras

JSC_SRCD=${BASE_DIR}/vendor/JavaScriptCore.framework
JSC_DEST=${ZIP_SRCD}

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds

export TAP_TIMEOUT=120

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

cd ${WORKSPACE}
echo ============================================  sync couchbase-lite-ios
echo ============================================  to ${GITSPEC}

if [[ -d couchbase-lite-ios ]] ; then rm -rf couchbase-lite-ios ; fi
git clone       https://github.com/couchbase/couchbase-lite-ios.git   couchbase-lite-ios

cd  couchbase-lite-ios
if [[ !  `git branch | grep ${GITSPEC}` ]]
    then
    git branch -t ${GITSPEC} origin/${GITSPEC}
fi
git fetch
git checkout      ${GITSPEC}
git pull  origin  ${GITSPEC}
git submodule update --init --recursive
git show --stat

cd ${WORKSPACE}
echo ============================================  sync cblite-build
echo ============================================  to master

if [[ ! -d cblite-build ]] ; then git clone https://github.com/couchbaselabs/cblite-build.git ; fi
cd  cblite-build
git checkout      master
git pull  origin  master
git submodule update --init --recursive
git show --stat

DOC_ZIP_FILE=cblite_ios_${REVISION}_Documentation.zip
DOC_ZIP_PATH=${BASE_DIR}/${DOC_ZIP_FILE}
                                                                   # required by "Documentation" target
DERIVED_FILE_DIR=${REL_SRCD}/Documentation                         #  where the doc files are generated
TARGET_BUILD_DIR=${REL_SRCD}/com.couchbase.CouchbaseLite.docset    #  where the doc set ends up
DOC_ZIP_ROOT_DIR=${REL_SRCD}/${REVISION}

mkdir -p ${TARGET_BUILD_DIR}

cd ${WORKSPACE}/couchbase-lite-ios
for TARGET in "CBL iOS" "CBL Listener iOS" "LiteServ" "CBLJSViewCompiler" "LiteServ App" "Documentation"
  do
    echo ============================================  iOS target: ${TARGET}
    echo ============================================  iOS target: ${TARGET}  >>  ${LOG_FILE}
    ( xcodebuild -target "${TARGET}"  2>&1 )                                  >>  ${LOG_FILE}
    if  [[ -e ${LOGFILE} ]]
        then
        echo
        echo "======================================= ${LOGFILE}"
        echo ". . ."
        tail  ${LOG_TAIL}                             ${LOGFILE}
    fi
done

echo  ============================================== package ${DOC_ZIP_FILE}
mv     ${DERIVED_FILE_DIR} ${DOC_ZIP_ROOT_DIR}
pushd  ${REL_SRCD}         2>&1 > /dev/null
zip -r ${DOC_ZIP_PATH} ${REVISION}
popd                        2>&1 > /dev/null

echo  ============================================== prepare ${ZIP_FILE}
if [[ -e ${ZIP_SRCD} ]] ; then rm -rf ${ZIP_SRCD} ; fi
mkdir -p ${ZIP_SRCD}

cp  -r   ${RIO_SRCD}/*             ${RIO_DEST}
#cp -r   ${REL_SRCD}/LiteServ*     ${REL_DEST}
cp  -r   ${LSA_SRCD}/LiteServ.app  ${LSA_DEST}
cp       ${LIB_SRCF}               ${LIB_DEST}
cp  -r   ${JSC_SRCD}               ${JSC_DEST}
cp       ${README_F}               ${RME_DEST}
cp       ${LICENSEF}               ${LIC_DEST}

cd       ${ZIP_SRCD}/CouchbaseLite.framework
rm -rf PrivateHeaders

cd       ${ZIP_SRCD}
rm -rf CouchbaseLite.framework.dSYM
rm -rf CouchbaseLiteListener.framework.dSYM
rm -rf LiteServ.app.dSYM

echo  ============================================== package ${ZIP_FILE}
cd       ${ZIP_SRCD}
zip -r   ${ZIP_PATH} *

echo  ============================================== upload ${CBFS_URL}/${ZIP_FILE}
curl -XPUT --data-binary @${ZIP_PATH} ${CBFS_URL}/${ZIP_FILE}

echo  ============================================== upload ${CBFS_URL}/${DOC_ZIP_FILE}
curl -XPUT --data-binary @${DOC_ZIP_PATH} ${CBFS_URL}/${DOC_ZIP_FILE}

# echo  ============================================== update default value of test jobs
# ${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl  -j mobile_functional_tests_ios_${GITSPEC}      -p LITESERV_VERSION  -v ${BUILD_NUMBER}
# ${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl  -j mobile_functional_tests_android_${GITSPEC}  -p LITESERV_VERSION  -v ${BUILD_NUMBER}

echo  ============================================== test

