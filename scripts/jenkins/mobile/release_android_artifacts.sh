#!/bin/bash
#          
#          run from manual jobs:   release_android_artifacts_master
#                                  release_android_artifacts_100
#          
#           to download an android ZIP file,
#              rename the couchbase JARs inside,
#              rename the ZIP file and upload it to S3,
#              and upload the cblite JARS to our maven repository.
#          
#          called with paramters:
#          
#            branch name          master, release/1.0.0, etc.
#            BLD_TO_RELEASE       number of ZIP file to download (0.0.0-1234)
#            RELEASE_NUMBER       number/name to release as      (0.0.0, 0.0.0-beta)
#            EDITION              'community' or 'enterprise'
#          
source ~/.bash_profile
export DISPLAY=:0
set -e

CURL_CMD="curl --fail --retry 10"
PUT_CMD="s3cmd put -P"

LIST_OF_JARS="                \
              android         \
              java-core       \
              java-javascript \
              java-listener   \
             "
MAVEN_UPLOAD_CREDENTS=${MAVEN_UPLOAD_USERNAME}:${MAVEN_UPLOAD_PASSWORD}

REPOURL=http://files.couchbase.com/maven2
GRP_URL=com/couchbase/lite

#LOG_TAIL=-24


function usage
    {
    echo -e "\nuse:  ${0}   branch  bld_to_release  release_number  edition\n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
BLD_TO_RELEASE=${2}
if [[ ${BLD_TO_RELEASE} =~ '([0-9.]*)-'  ]]
  then
    VERSION=${BASH_REMATCH[1]}
    PKGSTORE=s3://packages.northscale.com/latestbuilds/mobile/${VERSION}
else
    echo "illegal value for BLD_TO_RELEASE: ${BLD_TO_RELEASE}"
    exit 88
fi

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
RELEASE_NUMBER=${3}


if [[ ! ${4} ]] ; then usage ; exit 66 ; fi
EDITION=${4}

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

ANDROID_JAR_DIR=${WORKSPACE}/android/jar


function change_jar_version
    {
    local PROD=$1
    local EXTN=$2
    local OLDV=$3
    local NEWV=$4
    echo +++++++++++++++++++++++++  changing version on ${PROD} from ${OLDV} to ${NEWV}
    echo ::::::::: ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${OLDV}.${EXTN}
    echo ::::::::: ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${OLDV}.pom
    
    mv  ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${OLDV}.${EXTN}                                                                    ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${NEWV}.${EXTN} 
    cat ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${OLDV}.pom | sed -e "s,<version>${OLDV}</version>,<version>${NEWV}</version>,g" > ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${NEWV}.pom
    rm  ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${OLDV}.pom
    echo +++++++++++++++++++++++++  created new artifact:  ${PROD}-${NEWV}.${EXTN}
    }

function prepare_bucket
    {
    NEW_BUCKET=$1
    echo "DEBUG:  preparing bucket...........................  ${NEW_BUCKET}"
    
    if [[     ! `${CURL_CMD} --user ${MAVEN_UPLOAD_CREDENTS}   ${NEW_BUCKET}` ]]
        then
        echo "DEBUG:  creating bucket........................  ${NEW_BUCKET}"
        ${CURL_CMD}   --user ${MAVEN_UPLOAD_CREDENTS} -XMKCOL  ${NEW_BUCKET}
    fi
    }

function upload_new_package
    {
    local PROD=$1
    local EXTN=$2
    local NEWV=$3
    
    JARFILE=${PROD}-${NEWV}.${EXTN}
    POMFILE=${PROD}-${NEWV}.pom
    echo "UPLOADING ${PROD} to .... maven repo:  ${REPOURL}/${GRP_URL}/${PROD}/${NEWV}"
    
    ${CURL_CMD} --user ${MAVEN_UPLOAD_CREDENTS} -XPUT --data-binary  @${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${JARFILE}  ${REPOURL}/${GRP_URL}/${PROD}/${NEWV}/${JARFILE}
    ${CURL_CMD} --user ${MAVEN_UPLOAD_CREDENTS} -XPUT --data-binary  @${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${POMFILE}  ${REPOURL}/${GRP_URL}/${PROD}/${NEWV}/${POMFILE}
    }


##############################################################################   S T A R T
echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

rm   -rf  ${ANDROID_JAR_DIR}
mkdir -p  ${ANDROID_JAR_DIR}
cd        ${ANDROID_JAR_DIR}
echo ============================================  download ${PKGSTORE}/${AND_ZIP_SRC}

wget  --no-verbose  ${PKGSTORE}/${AND_ZIP_SRC}
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

echo ============================================  uploading ${PKGSTORE}/${AND_ZIP_DST}
${PUT_CMD}  ${ANDROID_JAR_DIR}/${AND_ZIP_DST}                ${PKGSTORE}/${AND_ZIP_DST}

echo ============================================  prepare buckets
                              prepare_bucket ${REPOURL}/${GRP_URL}
for J in ${LIST_OF_JARS} ; do prepare_bucket ${REPOURL}/${GRP_URL}/${J} ; prepare_bucket ${REPOURL}/${GRP_URL}/${J}/${RELEASE_NUMBER} ; done

cd ${ANDROID_JAR_DIR}
echo ============================================  upload to maven repository

upload_new_package  android          aar  ${RELEASE_NUMBER}
upload_new_package  java-core        jar  ${RELEASE_NUMBER}
upload_new_package  java-javascript  jar  ${RELEASE_NUMBER}
upload_new_package  java-listener    jar  ${RELEASE_NUMBER}

echo ============================================ `date`
