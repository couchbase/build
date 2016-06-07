#!/bin/bash -ex
#          
#    run by jenkins couchbase-lite-net jobs:
#          
#    with required paramters:
#   
#          branch_name    framework   platform    version    bld_num   repo_sha  target            toolchain
#             
#    e.g.: master         net35       osx         1.3.0      0000      no_sha    Release_Testing   mono
#
#    and optional parameters:
#    
#        REPO_SHA  --  
#        SKIP_TEST --  
#          
#    ErrorCode:
#        -1 = Incorrect input parameters
#        -2 = Build failed
#        -3 = Unit test failed
#
set -e

function usage
    {
    echo "Incorrect parameters..."
    echo -e "\nUsage:  ${0}   branch_name  framework  platform  version  bld_num  commit_sha target\n\n"
    }

if [[ "$#" < 5 ]] ; then usage ; exit 11 ; fi

# enable nocasematch
shopt -s nocasematch

BRANCH=${1}

FRAMEWORK=${2}

PLATFORM=${3}

VERSION=${4}

BLD_NUM=${5}

if [[ $6 ]] ; then  echo "setting REPO_SHA to $6"       ; REPO_SHA=$6       ; else REPO_SHA="no_sha"            ; fi
if [[ $7 ]] ; then  echo "using TARGET $7"              ; TARGET=$7         ; else TARGET="Release_Testing"     ; fi
if [[ $8 ]] ; then  echo "using TOOLCHAIN $8"       	; TOOLCHAIN=$8      ; else TOOLCHAIN="mono"             ; fi
if [[ $9 ]] ; then  echo "setting TEST_OPTIONS to $9"   ; TEST_OPTIONS=$9   ; else TEST_OPTIONS="None"          ; fi

if [[ $BRANCH =~ feature  ]]
then
    LATESTBUILDS=http://latestbuilds.hq.couchbase.com/couchbase-lite-net/0.0.1/${BRANCH}/${BLD_NUM}
else
    LATESTBUILDS=http://latestbuilds.hq.couchbase.com/couchbase-lite-net/${VERSION}/${BLD_NUM}
fi

echo ============================================== `date`

FRAMEWORK_DIR=${WORKSPACE}/${VERSION}/${FRAMEWORK}
BASE_DIR=${FRAMEWORK_DIR}/couchbase-lite-net
SRC_DIR=${BASE_DIR}/src
BUILD_FRAMEWORK=Couchbase.Lite.${FRAMEWORK}
BUILD_SLN=${SRC_DIR}/${BUILD_FRAMEWORK}.sln
NATIVES_DIR=/latestbuilds/mobiledeps/cbforest/${VERSION}

STAGING_DIR=${BASE_DIR}/staging
LITE_BIN=${STAGING_DIR}/Couchbase.Lite
LSTNR_BIN=${STAGING_DIR}/Couchbase.Lite.Listener
LSTNR_BNJR_BIN=${STAGING_DIR}/Couchbase.Lite.Listener.Bonjour
SQLITE_BIN=${STAGING_DIR}/Couchbase.Lite.Storage.SystemSQLite
SQLCIPHER_BIN=${STAGING_DIR}/Couchbase.Lite.Storage.SQLCipher
FORESTDB_BIN=${STAGING_DIR}/Couchbase.Lite.Storage.ForestDB

BUILD_OUTPUT=("${LITE_BIN}" "${LSTNR_BIN}" "${LSTNR_BNJR_BIN}" "${SQLITE_BIN}" "${SQLCIPHER_BIN}" "${FORESTDB_BIN}")

# disable nocasematch
shopt -u nocasematch

if [[ ! -d ${FRAMEWORK_DIR} ]] ; then  mkdir -p ${FRAMEWORK_DIR} ; fi
cd         ${FRAMEWORK_DIR}
echo ======== sync couchbase-lite-net ===================
pwd
if [[ ! -d couchbase-lite-net ]] ; then git clone https://github.com/couchbase/couchbase-lite-net.git ; fi
cd         couchbase-lite-net

git checkout --track -B ${BRANCH} origin/${BRANCH}

if [ ${REPO_SHA} == "no_sha" ]
then
    git pull origin ${BRANCH}
else
    git checkout ${REPO_SHA}
fi

git submodule update --init --recursive

git show --stat

REPO_SHA=`git log --oneline --pretty="format:%H" -1`

if [[ ! -d ${NATIVES_DIR} ]]
then 
    echo "Missing native components at ${NATIVES_DIR}" 
    exit -2
fi

# Clean old build output since xbuild clean is too fragile
if [[ -d ${STAGING_DIR} ]] ; then rm -rf ${STAGING_DIR} ; fi

echo ======== Import Natives Dependency =============================
cd ${NATIVES_DIR}
dirs=(*/)                       # array of dirs
num_dirs=${#dirs[@]}            # size of array
last_index=$(($num_dirs -1))    # calc index of last dir
last_dir=${dirs[$last_index]}

BUILD_OPTIONS=/p:Platform="Any CPU"

if [[ ${FRAMEWORK} =~ "Net45" ]] || [[ ${FRAMEWORK} =~ "Net35" ]] 
then
    cd ${last_dir}
    cp -f libCBForest-Interop.so ${SRC_DIR}/StorageEngines/ForestDB/CBForest/CSharp/prebuilt
    cp -f libCBForest-Interop.dylib ${SRC_DIR}/StorageEngines/ForestDB/CBForest/CSharp/prebuilt
    cp -rf x86 ${SRC_DIR}/StorageEngines/ForestDB/CBForest/CSharp/prebuilt/
    cp -rf x64 ${SRC_DIR}/StorageEngines/ForestDB/CBForest/CSharp/prebuilt/
elif [[ ${FRAMEWORK} =~ "Android" ]]
then
    cd ${last_dir}
    cp -rf x86 ${SRC_DIR}/StorageEngines/ForestDB/CBForest/CSharp/prebuilt/
    cp -rf x86_64 ${SRC_DIR}/StorageEngines/ForestDB/CBForest/CSharp/prebuilt/
    cp -rf mips64 ${SRC_DIR}/StorageEngines/ForestDB/CBForest/CSharp/prebuilt/
    cp -rf arm64-v8a ${SRC_DIR}/StorageEngines/ForestDB/CBForest/CSharp/prebuilt/
    cp -rf armeabi-v7a ${SRC_DIR}/StorageEngines/ForestDB/CBForest/CSharp/prebuilt/
elif [[ ${FRAMEWORK} =~ "iOS" ]]
then
    cd ${last_dir}
    cp -f libCBForest-Interop.a ${SRC_DIR}/StorageEngines/ForestDB/CBForest/CSharp/prebuilt
    BUILD_OPTIONS=/p:Platform=iPhone
fi

set +e
cd ${BASE_DIR}
echo ================ Build Preparation ==========================
MONO_TEXTTOOL="/Applications/Xamarin Studio.app/Contents/Resources/lib/monodevelop/AddIns/MonoDevelop.TextTemplating/TextTransform.exe"
DASSEMBLYINFO_DIR=src/Couchbase.Lite.Shared/Properties
DASSEMBLYINFO_TEMPLATE=DynamicAssemblyInfo.tt
DASSEMBLYINFO_CSHARP=DynamicAssemblyInfo.cs

cd ${DASSEMBLYINFO_DIR}
mono "${MONO_TEXTTOOL}" ${DASSEMBLYINFO_TEMPLATE} -out ${DASSEMBLYINFO_CSHARP}

cd ${BASE_DIR}
echo ================ Build ==========================
echo "Building product=${BUILD_FRAMEWORK} ${PLATFORM}"
LOG_FILE=${FRAMEWORK}_build_results.log
BUILD_CMD="xbuild /p:Configuration=${TARGET} /p:Archive=true"

${BUILD_CMD} "${BUILD_OPTIONS}"  ${BUILD_SLN} 2>&1 >> ${LOG_FILE}

# Move build logs for archiving
mv -f ${LOG_FILE} ${WORKSPACE}/${VERSION}

echo ======== Verify Build =======================
for bld_bin in "${BUILD_OUTPUT[@]}"
  do
    if [[ ! -d ${bld_bin} ]]
    then
        echo "..............................BUILD FAILED! No Output: ${bld_bin}"
        exit -2
    fi
done

echo "..............................BUILD Success!" 
ls -l ${STAGING_DIR}

echo ======== Test ================================ `date`
echo ........................ running unit test
if [[ ${TEST_OPTIONS} =~ "None" ]]
then
    echo "..............................SKIP Test!"
else
    echo "..............................Running Test!"
fi

test_result=$?
if [ ${test_result} -ne "0" ]
then
    echo "########################### Unit Test FAILED! Results = ${test_result}"
    exit -3
fi

echo ................................... upload ${FRAMEWORK} internally to ${LATESTBUILDS}

echo ============================================== `date`
