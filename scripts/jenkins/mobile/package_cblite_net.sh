#!/bin/bash -ex
#          
#    run by jenkins couchbase-lite-net-packaging job:
#          
#    with required paramters:
#   
#          branch_name    platform    version    bld_num   target    toolchain
#             
#    e.g.: master         osx         1.3.0      0000      Release   mono
#
#    and optional parameters:
#    
#        REPO_SHA  --  
#          
#    ErrorCode:
#        -1 = Incorrect input parameters
#        -2 = Failed importing binary packages 
#        -3 = Failed nuget packing
#
set -e

function usage
    {
    echo "Incorrect parameters..."
    echo -e "\nUsage:  ${0}   branch_name  target  platform  version  bld_num  commit_sha\n\n"
    }

if [[ "$#" < 3 ]] ; then usage ; exit 1 ; fi

shopt -s nocasematch

BRANCH=${1}

VERSION=${2}

BLD_NUM=${3}

if [[ $4 ]] ; then  echo "setting REPO_SHA to $4"       ; REPO_SHA=$4       ; else REPO_SHA="no_sha"    ; fi

if [[ $BRANCH =~ feature  ]]
then
    LATESTBUILDS=http://latestbuilds.hq.couchbase.com/couchbase-lite-net/0.0.1/${BRANCH}/${BLD_NUM}
else
    LATESTBUILDS=http://latestbuilds.hq.couchbase.com/couchbase-lite-net/${VERSION}/${BLD_NUM}
fi

echo ============================================== `date`

PROD_DIR=${WORKSPACE}/${VERSION}/packaging
BASE_DIRNAME=couchbase-lite-net
BASE_DIR=${PROD_DIR}/${BASE_DIRNAME}
REL_DIR=${BASE_DIR}/release
STAGING_DST=${BASE_DIR}/staging
STAGING_SRC=/latestbuilds/couchbase-lite-net/${VERSION}/${BLD_NUM}/staging

BUILD_PKGS=("Couchbase.Lite" "Couchbase.Lite.Listener" "Couchbase.Lite.Listener.Bonjour" "Couchbase.Lite.Storage.SystemSQLite" "Couchbase.Lite.Storage.CustomSQLite" "Couchbase.Lite.Storage.SQLCipher" "Couchbase.Lite.Storage.ForestDB")
NUGET_PKGS=("couchbase-lite" "couchbase-lite-listener" "couchbase-lite-listener-bonjour" "couchbase-lite-storage-systemsqlite" "couchbase-lite-storage-customsqlite" "couchbase-lite-storage-sqlcipher" "couchbase-lite-storage-forestdb")

if [[ ${VERSION} == 1.4.0 ]] || [[ ${VERSION} > 1.4.0 ]]
then
    BUILD_PKGS=("${BUILD_PKGS[@]}" "Couchbase.Lite.Storage.CustomSQLite")
    NUGET_PKGS=("${NUGET_PKGS[@]}" "couchbase-lite-storage-customsqlite")
fi

# disable nocasematch
shopt -u nocasematch

if [[ ! -d ${PROD_DIR} ]] ; then  rm -rf ${PROD_DIR} ; fi
mkdir -p ${PROD_DIR}
cd ${PROD_DIR}

echo ======== sync couchbase-lite-net ===================
if [[ ! -d couchbase-lite-net ]] ; then git clone https://github.com/couchbase/couchbase-lite-net.git ${BASE_DIRNAME}; fi
cd ${BASE_DIR}

if [[ ${BRANCH} =~ "master" ]]
then
    echo "Packaging from ${BRANCH} branch"
else
    echo "Packaging from ${BRANCH} branch"
    git checkout --track -B ${BRANCH} origin/${BRANCH}
fi

if [ ${REPO_SHA} == "no_sha" ]
then
    git pull origin ${BRANCH}
else
    git checkout ${REPO_SHA}
fi

git pull origin ${BRANCH}

if [ ${REPO_SHA} == "no_sha" ]
then
    REPO_SHA=`git log --oneline --pretty="format:%H" -1`
fi

echo ======== Import Bin Packages =============================
if [[ -d ${STAGING_DST} ]] ; then  rm -rf ${STAGING_DST} ; fi
cp -r ${STAGING_SRC}  ${BASE_DIR}

cd ${STAGING_DST}

shopt -u nocasematch
echo ======== Verify all builds available =======================
for pkg in "${BUILD_PKGS[@]}"
  do
    if [[ ! -d ${pkg} ]]
    then
        echo "..............................PACKAGING FAILED! Missing BUILD: ${pkg}"
        exit 2
    fi
done

echo ======== NUGET Packing =============================
cd ${BASE_DIR}/packaging/nuget
for nupkg in "${NUGET_PKGS[@]}"
  do
    nuget pack -BasePath ${BASE_DIR} -Properties version=$NUGET_VERSION ${nupkg}.nuspec 
    result=$?
    if [ ${result} -ne "0" ]
    then
        echo "########################### FAILED NUGET PACKING ${nupkg}: ${result}"
        exit 3
    fi
done

echo ======== Clean up remote staging =============================
rm -rf ${STAGING_SRC}

echo ======== Copy nuget packages for release =============================
if [[ -d ${REL_DIR} ]] ; then  rm -rf ${REL_DIR} ; fi
mkdir -p ${REL_DIR}
mv ${BASE_DIR}/packaging/nuget/*.nupkg ${REL_DIR}
ls ${REL_DIR}

# Temporary copy LiteServ for (QE) internal consumption while Jim B. look for a better solution
echo ======== Copy LiteServ =============================
if [[ ${VERSION} == 1.4.0 ]] || [[ ${VERSION} > 1.4.0 ]]
then
    pushd ${BASE_DIR}/staging/LiteServ/net45
    zip -ry LiteServ *
    cp -f LiteServ.zip ${REL_DIR}
    popd
    pushd ${BASE_DIR}/staging/LiteServ/iOS/LiteServ.app
    zip -ry LiteServ-iOS *
    cp -f LiteServ-iOS.zip ${REL_DIR}
    popd
    cp -f ${BASE_DIR}/staging/LiteServ/Android/LiteServ.apk ${REL_DIR}
else
    pushd ${BASE_DIR}/staging/LiteServ
    zip -ry LiteServ *
    cp -f LiteServ.zip ${REL_DIR}
    popd
fi

echo ................................... upload internally to ${LATESTBUILDS}

echo ============================================== `date`
