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
    echo -e "\nuse:  ${0}   branch_name  release_number  build_number  edition target\n\n"
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
ZIPFILE_STAGING="zipfile_staging"
SQLCIPHER="libsqlcipher"
SDK=""

if [[ $OS =~ ios ]]
then
    if [[ ${VERSION} > 0.0.0 ]] && [[ ${VERSION} < 1.2.0 ]]
    then
        BUILD_TARGETS=("CBL iOS" "CBL Listener iOS" "LiteServ" "LiteServ App" "CBLJSViewCompiler" "Documentation")
    else
        BUILD_TARGETS=("CBL iOS" "CBL Listener iOS" "Documentation")
        PLATFORM="iOS"
    fi
    RIO_SRCD=${BUILDDIR}/Release-ios-universal
    REL_SRCD=${BUILDDIR}/Release
    if [[ ${VERSION} == 0.0.0 ]] || [[ ${VERSION} == 1.2.0 ]] || [[ ${VERSION} > 1.2.0 ]] 
    then
        LIB_SQLCIPHER=${BASE_DIR}/${SQLCIPHER}/libs/ios/libsqlcipher.a
        LIB_SQLCIPHER_DEST=${BASE_DIR}/${ZIPFILE_STAGING}
    fi
elif [[ $OS =~ tvos ]]
then
    BUILD_TARGETS=("CBL iOS" "CBL Listener iOS" "Documentation")
    RIO_SRCD=${BUILDDIR}/Release-tvos-universal
    REL_SRCD=${BUILDDIR}/Release-appletvos
    PLATFORM="tvOS"
    SDK="-sdk appletvos"
    LIB_SQLCIPHER=${BASE_DIR}/${SQLCIPHER}/libs/tvos/libsqlcipher.a
    LIB_SQLCIPHER_DEST=${BASE_DIR}/${ZIPFILE_STAGING}
elif [[ $OS =~ macosx ]]
then
    BUILD_TARGETS=("CBL Mac" "CBL Listener Mac" "LiteServ" "LiteServ App")
    if [[ ${VERSION} == 0.0.0 ]] || [[ ${VERSION} == 1.2.0 ]] || [[ ${VERSION} > 1.2.0 ]]
    then
        BUILD_TARGETS=("${BUILD_TARGETS[@]}" "CBL Mac+SQLCipher")
        PLATFORM="OS X"
        CBL_SQLCIPHER_SRC=${BUILDDIR}/Release-sqlcipher/CouchbaseLite.framework
        CBL_SQLCIPHER_DST=${BASE_DIR}/${ZIPFILE_STAGING}/CouchbaseLite.framework
        LIB_SQLCIPHER=${BASE_DIR}/${SQLCIPHER}/libs/osx/libsqlcipher.a
        LIB_SQLCIPHER_DEST=${BASE_DIR}/vendor/SQLCipher/libs/osx
    fi
    RIO_SRCD=${BUILDDIR}/Release
else
    echo -e "\nUnsupported OS:  ${OS}\n"
    exit 555
fi

LATESTBUILDS_CBL=http://latestbuilds.hq.couchbase.com/couchbase-lite-ios/${GITSPEC}/${VERSION}/${OS}/${REVISION}

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
REL_DEST=${BUILDDIR}/Release

LSA_SRCD=${BUILDDIR}/Release
LSA_DEST=${ZIP_SRCD}

if [[ ${VERSION} > 0.0.0 ]] && [[ ${VERSION} < 1.2.0 ]]
then
    LIB_FORESTDB=${BUILDDIR}/Release-CBLForestDBStorage-ios-universal/libCBLForestDBStorage.a
    LIB_SRCD=${BUILDDIR}/Release-CBLJSViewCompiler-ios-universal
    LIB_JSVC=${LIB_SRCD}/libCBLJSViewCompiler.a
    LIB_DEST=${ZIP_SRCD}/Extras
fi

export TAP_TIMEOUT=120

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

cd ${WORKSPACE}
echo ============================================  sync couchbase-lite-ios
echo ============================================  to ${GITSPEC} into ${WORKSPACE}/couchbase-lite-${OS}

if [[ -d couchbase-lite-${OS} ]] ; then rm -rf couchbase-lite-${OS} ; fi
git clone       https://github.com/couchbase/couchbase-lite-ios.git   couchbase-lite-${OS}

# master branch maps to "0.0.0" for backward compatibility with pre-existing jobs 
if [[ ${GITSPEC} =~ "0.0.0" ]]
then
    BRANCH=master
else
    BRANCH=${GITSPEC}
fi

cd  couchbase-lite-${OS}
if [[ !  `git branch | grep ${BRANCH}` ]]
    then
    git branch -t ${BRANCH} origin/${BRANCH}
fi
git fetch
git checkout      ${BRANCH}
git pull  origin  ${BRANCH}
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
DOC_ZIP_ROOT_DIR=${REL_DEST}/${REVISION}

if [[ $OS =~ ios  ]] || [[ $OS =~ tvos ]]
then
    if [[ ! -e ${REL_DEST} ]] ; then mkdir -p ${REL_DEST} ; fi
    TARGET_BUILD_DIR=${REL_DEST}/com.couchbase.CouchbaseLite.docset    #  where the doc set ends up
    mkdir -p ${TARGET_BUILD_DIR}
fi

echo  ============================================== prepare ${ZIP_FILE}
if [[ -e ${ZIP_SRCD} ]] ; then rm -rf ${ZIP_SRCD} ; fi
mkdir -p ${ZIP_SRCD}

cd ${BASE_DIR}
if [[ ${VERSION} == 0.0.0 ]] || [[ ${VERSION} == 1.2.0 ]] || [[ ${VERSION} > 1.2.0 ]]
then
    # Temporary solution to download prebuilt sqlcipher from couchbaselab
    if [[ -d ${SQLCIPHER} ]] ; then rm -rf ${SQLCIPHER} ; fi
    git clone https://github.com/couchbaselabs/couchbase-lite-libsqlcipher.git ${SQLCIPHER}
    cd ${SQLCIPHER}
    git checkout ${BRANCH} 
    cd ${BASE_DIR}
    if [[ ! -e ${LIB_SQLCIPHER_DEST} ]] ; then mkdir -p ${LIB_SQLCIPHER_DEST} ; fi
    cp ${LIB_SQLCIPHER} ${LIB_SQLCIPHER_DEST}
fi

echo "Building target=${OS} platform=${PLATFORM} ${SDK}"
XCODE_CMD="xcodebuild CURRENT_PROJECT_VERSION=${BLD_NUM} CBL_VERSION_STRING=${VERSION} CBL_SOURCE_REVISION=${REPO_SHA}"

echo "using command: ${XCODE_CMD}"
echo "using command: ${XCODE_CMD}"                                            >>  ${LOG_FILE}

for TARGET in "${BUILD_TARGETS[@]}"
  do
    echo ============================================  ${OS} target: ${TARGET}
    echo ============================================  ${OS} target: ${TARGET}	>>  ${LOG_FILE}
    if [[ ${VERSION} > 0.0.0 ]] && [[ ${VERSION} < 1.2.0 ]]
    then
        ( ${XCODE_CMD} -target "${TARGET}"  2>&1 )	>>  ${LOG_FILE}
    else
        ( ${XCODE_CMD} -destination "platform=${PLATFORM}" ${SDK} -target "${TARGET}"  2>&1 )	>>  ${LOG_FILE}
    fi
    if  [[ -e ${LOGFILE} ]]
        then
        echo
        echo "======================================= ${LOGFILE}"
        echo ". . ."
        tail  ${LOG_TAIL}                             ${LOGFILE}
    fi
done

if [[ $OS =~ ios  ]] || [[ $OS =~ tvos ]]
then 
    echo  ============================================== package ${DOC_ZIP_FILE}
    DOC_LOG=${WORKSPACE}/doc_zip.log
    if [[ -e ${DOC_LOG} ]] ; then rm -f ${DOC_LOG} ; fi

    mv     ${DERIVED_FILE_DIR} ${DOC_ZIP_ROOT_DIR}
    pushd  ${REL_DEST}         2>&1 > /dev/null

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

echo  ============================================== update ${ZIP_FILE}
cp  -R   ${RIO_SRCD}/*             ${RIO_DEST}
cp       ${README_F}               ${RME_DEST}
cp       ${LICENSEF}               ${LIC_DEST}

if [[ $OS =~ macosx ]]
then
    if [[ ${VERSION} == 0.0.0 ]] || [[ ${VERSION} == 1.2.0 ]] || [[ ${VERSION} > 1.2.0 ]] 
    then
        rm -rf ${CBL_SQLCIPHER_DST}
        cp -R ${CBL_SQLCIPHER_SRC} ${CBL_SQLCIPHER_DST}
    fi
else
    if [[ ${VERSION} > 0.0.0 ]] && [[ ${VERSION} < 1.2.0 ]]
    then 
        cp ${LIB_JSVC} ${LIB_DEST}
        cp ${LIB_FORESTDB} ${LIB_DEST}
        cp  -R   ${LSA_SRCD}/LiteServ.app  ${LSA_DEST}
    fi
fi

cd ${ZIP_SRCD}/CouchbaseLite.framework
rm -rf PrivateHeaders

cd ${ZIP_SRCD}
rm -rf *.dSYM

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

