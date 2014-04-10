#!/bin/bash
#          
#          run from manual jobs:   release_android_artifacts_master
#                                  release_android_artifacts_100
#          
#           to download an android ZIP file,
#              rename the couchbase JARs inside,
#              rename the ZIP file and upload it to cbfs,
#              and upload the cblite JARS to our maven repository.
#          
#          called with paramters:
#          
#            branch name          master, release/1.0.0, etc.
#            BLD_TO_RELEASE       number of ZIP file to download (0.0.0-1234)
#            RELEASE_NUMBER       number/name to release as      (0.0.0, 0.0.0-beta)
#            EDITION              'community' or 'enterprise'
#          
#source ~/.bash_profile
export DISPLAY=:0
set -e

function usage
    {
    echo -e "\nuse:  ${0}   branch  bld_to_release  release_number  edition\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
BLD_TO_RELEASE=${2}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
RELEASE_NUMBER=${3}

if [[ ! ${4} ]] ; then usage ; exit 66 ; fi
EDITION=${4}

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds


echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

if [[ ${EDITION} =~ 'community' ]]
    then
    AND_ZIP_SRC=couchbase-lite-${BLD_TO_RELEASE}-android-${EDITION}.zip
    AND_ZIP_DST=couchbase-lite-${RELEASE_NUMBER}-android-${EDITION}.zip
else
    AND_ZIP_SRC=couchbase-lite-${BLD_TO_RELEASE}-android.zip
    AND_ZIP_DST=couchbase-lite-${RELEASE_NUMBER}-android.zip
fi
    SRC_ROOTDIR=couchbase-lite-${BLD_TO_RELEASE}
    DST_ROOTDIR=couchbase-lite-${RELEASE_NUMBER}

#ANDROID_SRC_DIR=${WORKSPACE}/android/src
ANDROID_JAR_DIR=${WORKSPACE}/android/jar


function change_jar_version
    {
    local PROD=$1
    local EXTN=$2
    local OLDV=$3
    local NEWV=$4
    echo +++++++++++++++++++++++++  changing version on ${PROD} from ${OLDV} to ${NEWV}
 #  TMPDIR=${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}
 #  mkdir -p ${TMPDIR}
 #  echo ------ ${TMPDIR}
 #  pushd    ${TMPDIR} 2>&1 > /dev/null
    echo ::::::::: ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${OLDV}.${EXTN}
    echo ::::::::: ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${OLDV}.pom
    
    mv  ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${OLDV}.${EXTN}                                                                    ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${NEWV}.${EXTN} 
    cat ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${OLDV}.pom | sed -e "s,<version>${OLDV}</version>,<version>${NEWV}</version>,g" > ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${NEWV}.pom
    rm  ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${OLDV}.pom
    
 #  popd               2>&1 > /dev/null
 #  rm  -rf  ${TMPDIR}
    echo +++++++++++++++++++++++++  created new artifact:  ${PROD}-${NEWV}.${EXTN}
    }

# rm   -rf  ${ANDROID_SRC_DIR}
# mkdir -p  ${ANDROID_SRC_DIR}
# cd        ${ANDROID_SRC_DIR}
# echo ============================================  sync couchbase-lite-android-liteserv
# echo ============================================  to ${GITSPEC}
# 
# if [[ ! -d couchbase-lite-android-liteserv ]] ; then git clone https://github.com/couchbase/couchbase-lite-android-liteserv.git ; fi
# cd         couchbase-lite-android-liteserv
# git checkout      ${GITSPEC}
# git pull  origin  ${GITSPEC}
# git submodule init
# git submodule update
# git show --stat

rm   -rf  ${ANDROID_JAR_DIR}
mkdir -p  ${ANDROID_JAR_DIR}
cd        ${ANDROID_JAR_DIR}
echo ============================================  download ${CBFS_URL}/${AND_ZIP_SRC}

wget  --no-verbose  ${CBFS_URL}/${AND_ZIP_SRC}
unzip ${AND_ZIP_SRC}

echo ============================================  renumber to ${AND_ZIP_DST}
mv ${SRC_ROOTDIR}  ${DST_ROOTDIR}
cd                 ${DST_ROOTDIR}

change_jar_version  android          aar  ${BLD_TO_RELEASE}  ${RELEASE_NUMBER}
change_jar_version  java-core        jar  ${BLD_TO_RELEASE}  ${RELEASE_NUMBER}
change_jar_version  java-javascript  jar  ${BLD_TO_RELEASE}  ${RELEASE_NUMBER}
change_jar_version  java-listener    jar  ${BLD_TO_RELEASE}  ${RELEASE_NUMBER}

cd                 ${ANDROID_JAR_DIR}
zip  -r            ${AND_ZIP_DST}     ${DST_ROOTDIR}

echo ============================================  uploading ${CBFS_URL}/${AND_ZIP_DST}
curl -XPUT --data-binary  @${ANDROID_JAR_DIR}/${AND_ZIP_DST} ${CBFS_URL}/${AND_ZIP_DST}


echo ============================================  upload to maven repository
${WORKSPACE}/build/scripts/jenkins/mobile/upload-to-maven.sh  ${GITSPEC}  ${RELEASE_NUMBER}  ${ANDROID_JAR_DIR}/${DST_ROOTDIR}

echo ============================================ `date`
