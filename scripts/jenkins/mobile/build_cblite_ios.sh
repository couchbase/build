#!/bin/bash
#          
#          run by jenkins jobs 'build_cblite_ios_master', 'build_cblite_ios_100'
#          
#          with paramters:  branch_name  release_number  build_number  Edition
#          
#                 e.g.:     master           0.0.0         1234       community
#                           release/1.0.0    1.0.0         1234       enterprise
#          
source ~jenkins/.bash_profile
set -e

LOG_TAIL=-24


function usage
    {
    echo -e "\nuse:  ${0}   branch_name  release_number  build_number  edition\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

JOB_SUFX=${GITSPEC}
                      vrs_rex='([0-9]{1,})\.([0-9]{1,})\.([0-9]{1,})(\.([0-9]{1,}))?'
if [[ ${JOB_SUFX} =~ $vrs_rex ]]
    then
    JOB_SUFX=""
    for N in 1 2 3 5; do
        if [[ $N -eq 1 ]] ; then            JOB_SUFX=${BASH_REMATCH[$N]} ; fi
        if [[ $N -eq 2 ]] ; then JOB_SUFX=${JOB_SUFX}${BASH_REMATCH[$N]} ; fi
        if [[ $N -eq 3 ]] ; then JOB_SUFX=${JOB_SUFX}${BASH_REMATCH[$N]} ; fi
        if [[ $N -eq 5 ]] ; then JOB_SUFX=${JOB_SUFX}${BASH_REMATCH[$N]} ; fi
    done
fi

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
VERSION=${2}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
BLD_NUM=${3}
REVISION=${VERSION}-${BLD_NUM}

if [[ ! ${4} ]] ; then usage ; exit 66 ; fi
EDITION=${4}
EDN_PRFX=`echo ${EDITION} | tr '[a-z]' '[A-Z]'`

if [[ ! ${5} ]] ; then usage ; exit 55 ; fi
OS=${5}
EDN_PRFX=`echo ${OS} | tr '[a-z]' '[A-Z]'`

BASE_DIR=${WORKSPACE}/couchbase-lite-${OS}
BUILDDIR=${BASE_DIR}/build

if [[ $OS =~ ios  ]]
then
    BUILD_TARGETS=("CBL iOS" "CBL Listener iOS" "LiteServ" "CBLJSViewCompiler" "LiteServ App" "Documentation")
    RIO_SRCD=${BUILDDIR}/Release-ios-universal
elif [[ $OS =~ macosx  ]]
then
    BUILD_TARGETS=("CBL Mac" "CBL Listener Mac") 
    RIO_SRCD=${BUILDDIR}/Release
else
    echo -e "\nunsupported OS:  ${OS}\n"
    exit 555
fi

LATESTBUILDS_CBL=http://latestbuilds.hq.couchbase.com/couchbase-lite-ios/${OS}/${VERSION}/${REVISION}
#PKGSTORE=s3://packages.couchbase.com/builds/mobile/ios/${VERSION}/${REVISION}
#PUT_CMD="s3cmd put -P"

LOG_FILE=${WORKSPACE}/build_${OS}_results.log
if [[ -e ${LOG_FILE} ]] ; then rm -f ${LOG_FILE} ; fi

ZIP_FILE=couchbase-lite-${OS}-${EDITION}_${REVISION}.zip
ZIP_PATH=${BASE_DIR}/${ZIP_FILE}
ZIP_SRCD=${BASE_DIR}/zipfile_staging

DOC_ZIP_FILE=couchbase-lite-${OS}-${EDITION}_${REVISION}_Documentation.zip
DOC_ZIP_PATH=${BASE_DIR}/${DOC_ZIP_FILE}

LICENSED=${WORKSPACE}/build/license/couchbase-lite
LICENSEF=${LICENSED}/LICENSE_${EDITION}.txt
LIC_DEST=${ZIP_SRCD}/LICENSE.txt

README_D=${BASE_DIR}
README_F=${README_D}/README.md
RME_DEST=${ZIP_SRCD}

RIO_DEST=${ZIP_SRCD}

REL_SRCD=${BUILDDIR}/Release
REL_DEST=${ZIP_SRCD}

LSA_SRCD=${BUILDDIR}/Release
LSA_DEST=${ZIP_SRCD}

LIB_FORESTDB=${BUILDDIR}/Release-CBLForestDBStorage-ios-universal/libCBLForestDBStorage.a
LIB_SRCD=${BUILDDIR}/Release-CBLJSViewCompiler-ios-universal
LIB_SRCF=${LIB_SRCD}/libCBLJSViewCompiler.a
LIB_DEST=${ZIP_SRCD}/Extras

JSC_SRCD=${BASE_DIR}/vendor/JavaScriptCore.framework
JSC_DEST=${LIB_DEST}

export TAP_TIMEOUT=120

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

cd ${WORKSPACE}
echo ============================================  sync couchbase-lite-ios
echo ============================================  to ${GITSPEC} into ${WORKSPACE}/couchbase-lite-${OS}

if [[ -d couchbase-lite-${OS} ]] ; then rm -rf couchbase-lite-${OS} ; fi
git clone       https://github.com/couchbase/couchbase-lite-ios.git   couchbase-lite-${OS}

cd  couchbase-lite-${OS}
if [[ !  `git branch | grep ${GITSPEC}` ]]
    then
    git branch -t ${GITSPEC} origin/${GITSPEC}
fi
git fetch
git checkout      ${GITSPEC}
git pull  origin  ${GITSPEC}
git submodule update --init --recursive
git show --stat
REPO_SHA=`git log --oneline --pretty="format:%H" -1`


cd ${WORKSPACE}
echo ============================================  sync cblite-build
echo ============================================  to master into ${WORKSPACE}

if [[ ! -d cblite-build ]] ; then git clone https://github.com/couchbaselabs/cblite-build.git ; fi
cd  cblite-build
git checkout      master
git pull  origin  master
git submodule update --init --recursive
git show --stat
                                                                   # required by "Documentation" target
DERIVED_FILE_DIR=${REL_SRCD}/Documentation                         #  where the doc files are generated
DOC_ZIP_ROOT_DIR=${REL_SRCD}/${REVISION}

if [[ $OS =~ ios  ]]
then
    TARGET_BUILD_DIR=${REL_SRCD}/com.couchbase.CouchbaseLite.docset    #  where the doc set ends up
    mkdir -p ${TARGET_BUILD_DIR}
fi

XCODE_CMD="xcodebuild CURRENT_PROJECT_VERSION=${BLD_NUM} CBL_VERSION_STRING=${VERSION} CBL_SOURCE_REVISION=${REPO_SHA}"

echo "using command: ${XCODE_CMD}"
echo "using command: ${XCODE_CMD}"                                            >>  ${LOG_FILE}

cd ${WORKSPACE}/couchbase-lite-${OS}
for TARGET in "${BUILD_TARGETS[@]}"
  do
    echo ============================================  ${OS} target: ${TARGET}
    echo ============================================  ${OS} target: ${TARGET}  >>  ${LOG_FILE}
    ( ${XCODE_CMD} -target "${TARGET}"  2>&1 )                                >>  ${LOG_FILE}
    if  [[ -e ${LOGFILE} ]]
        then
        echo
        echo "======================================= ${LOGFILE}"
        echo ". . ."
        tail  ${LOG_TAIL}                             ${LOGFILE}
    fi
done


if [[ $OS =~ ios  ]]
then 
    echo  ============================================== package ${DOC_ZIP_FILE}
    DOC_LOG=${WORKSPACE}/doc_zip.log
    if [[ -e ${DOC_LOG} ]] ; then rm -f ${DOC_LOG} ; fi

    mv     ${DERIVED_FILE_DIR} ${DOC_ZIP_ROOT_DIR}
    pushd  ${REL_SRCD}         2>&1 > /dev/null

    ( zip -ry ${DOC_ZIP_PATH} ${REVISION}  2>&1 )                                  >>  ${DOC_LOG}
    if  [[ -e ${DOC_LOG} ]]
        then
        echo
        echo "======================================= ${DOC_LOG}"
        echo ". . ."
        tail  ${LOG_TAIL}                             ${DOC_LOG}
    fi
    popd                        2>&1 > /dev/null
fi

echo  ============================================== prepare ${ZIP_FILE}
if [[ -e ${ZIP_SRCD} ]] ; then rm -rf ${ZIP_SRCD} ; fi
mkdir -p ${ZIP_SRCD}

cp  -R   ${RIO_SRCD}/*             ${RIO_DEST}
cp       ${README_F}               ${RME_DEST}
cp       ${LICENSEF}               ${LIC_DEST}

if [[ $OS =~ ios  ]]
then 
    cp ${LIB_SRCF} ${LIB_DEST}
    cp ${LIB_FORESTDB} ${LIB_DEST}
    cp  -R   ${LSA_SRCD}/LiteServ.app  ${LSA_DEST}
fi

cd       ${ZIP_SRCD}/CouchbaseLite.framework
rm -rf PrivateHeaders

cd       ${ZIP_SRCD}
rm -rf CouchbaseLite.framework.dSYM
rm -rf CouchbaseLiteListener.framework.dSYM
rm -rf LiteServ.app.dSYM

echo  ============================================== package ${ZIP_FILE}
ZIP_LOG=${WORKSPACE}/doc_zip.log
if [[ -e ${ZIP_LOG} ]] ; then rm -f ${ZIP_LOG} ; fi

cd         ${ZIP_SRCD}
( zip -ry   ${ZIP_PATH} *  2>&1 )                                              >>  ${ZIP_LOG}
if  [[ -e ${ZIP_LOG} ]]
    then
    echo
    echo "======================================= ${ZIP_LOG}"
    echo ". . ."
    tail  ${LOG_TAIL}                             ${ZIP_LOG}
fi

#echo  ============================================== upload ${PKGSTORE}/${ZIP_FILE}
#${PUT_CMD}  ${ZIP_PATH}                                     ${PKGSTORE}/${ZIP_FILE}

#echo  ============================================== upload ${PKGSTORE}/${DOC_ZIP_FILE}
#${PUT_CMD}  ${DOC_ZIP_PATH}                                 ${PKGSTORE}/${DOC_ZIP_FILE}

echo        ........................... uploading internally to ${LATESTBUILDS_CBL}

echo ============================================== `date`

# changes required in mobile_functional_tests_xxx to support macosx
#if [[ $OS =~ ios  ]]
#then
#    echo  ============================================== update default value of test and release jobs
#    SET_SCRIPT=${WORKSPACE}/build/scripts/cgi/set_jenkins_default_param.pl

#    ${SET_SCRIPT}  -j prepare_release_ios_${JOB_SUFX}              -p ${EDN_PRFX}_BLD_TO_RELEASE    -v ${REVISION}
#    ${SET_SCRIPT}  -j mobile_functional_tests_ios_${JOB_SUFX}      -p ${EDN_PRFX}_LITESERV_VERSION  -v ${REVISION}
#echo  ============================================== test
#fi

