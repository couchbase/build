#!/bin/bash -x
#          
#          run from manual jobs:   prepare_release_android_master
#                                  prepare_release_android_100
#          
#           to download an android ZIP file,
#              rename the couchbase JARs inside,
#              rename the ZIP file and upload it to S3,
#              and upload the cblite JARS to our maven repository.
#          
#          called with paramters:
#          
#            BLD_NUM       number of ZIP file to download (0.0.0-1234)
#            REL_NUM       number/name to release as      (0.0.0, 0.0.0-beta)
#            EDITION       'community' or 'enterprise'
#          
source ~/.bash_profile
export DISPLAY=:0
set -e

CURL_CMD="curl --fail --retry 10"

PUT_CMD="s3cmd put -P"
GET_CMD="s3cmd get"

LIST_OF_JARS="                \
              couchbase-lite-android          \
              couchbase-lite-java-core        \
              couchbase-lite-java-javascript  \
              couchbase-lite-java-listener    \
             "
MAVEN_UPLOAD_CREDENTS=${MAVEN_UPLOAD_USERNAME}:${MAVEN_UPLOAD_PASSWORD}

REPOURL=http://files.couchbase.com/maven2
GRP_URL=com/couchbase/lite


function usage
    {
    echo -e "\nuse:  ${0}   bld_to_release  release_number  edition\n\n"
    }

if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
BLD_NUM=${1}
                     vrs_rex='([0-9]{1,}\.[0-9]{1,}\.[0-9]{1,})'
if [[ ${BLD_NUM} =~ $vrs_rex  ]]
  then
    VERSION=${BASH_REMATCH[1]}
else
    echo "illegal value for BLD_NUM: "'>>'${BLD_NUM}'<<'
    exit 88
fi

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
REL_NUM=${2}

PKG_SRC=s3://packages.couchbase.com/builds/mobile/android/${VERSION}/${BLD_NUM}
PKG_DEST=s3://packages.couchbase.com/builds/mobile/android/${VERSION}/${REL_NUM}


if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
EDITION=${3}

AND_ZIP_SRC=couchbase-lite-android-${EDITION}_${BLD_NUM}.zip
AND_ZIP_DST=couchbase-lite-android-${EDITION}_${REL_NUM}.zip
SRC_ROOTDIR=couchbase-lite-${BLD_NUM}
DST_ROOTDIR=couchbase-lite-${REL_NUM}

ANDROID_JAR_DIR=${WORKSPACE}/android/jar


function change_jar_version
    {
    local PROD=$1
    local EXTN=$2
    local OLDV=$3
    local NEWV=$4
    local NOPOM=$5
    local HYPHEN=$6

    if [[ "${HYPHEN}" = "" ]]; then
        HYPHEN=-
    fi

    echo +++++++++++++++++++++++++  changing version on ${PROD} from ${OLDV} to ${NEWV}
    echo ::::::::: ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}${HYPHEN}${OLDV}.${EXTN}
    if [[ ${NOPOM} = "" ]]; then
	echo ::::::::: ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}${HYPHEN}${OLDV}.pom
    fi
    
    mv  ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}${HYPHEN}${OLDV}.${EXTN}                                                                    ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${NEWV}.${EXTN} 
    if [[ ${NOPOM} = "" ]]; then
	cat ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}${HYPHEN}${OLDV}.pom | sed -e "s,<version>${OLDV}</version>,<version>${NEWV}</version>,g" > ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${NEWV}.pom
	rm  ${ANDROID_JAR_DIR}/${DST_ROOTDIR}/${PROD}-${OLDV}.pom
    fi
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
echo ============================================  download ${PKG_SRC}/${AND_ZIP_SRC}

${GET_CMD}  ${PKG_SRC}/${AND_ZIP_SRC}
pwd
unzip ${AND_ZIP_SRC}

# Move javadocs and source into dest_dir so they can be renamed.
# Probably the build_cblite_android step should put them there.
echo ============================================  move javadoc and source to same dir
mv couchbase-lite-android-*.jar ${SRC_ROOTDIR}

echo ============================================  renumber to ${AND_ZIP_DST}
mv ${SRC_ROOTDIR}  ${DST_ROOTDIR}

change_jar_version  couchbase-lite-android           aar  ${BLD_NUM}  ${REL_NUM}  NO_POM
change_jar_version  couchbase-lite-android           jar  ${BLD_NUM}  ${REL_NUM}
change_jar_version  couchbase-lite-java-core         jar  ${BLD_NUM}  ${REL_NUM}
change_jar_version  couchbase-lite-java-javascript   jar  ${BLD_NUM}  ${REL_NUM}
change_jar_version  couchbase-lite-java-listener     jar  ${BLD_NUM}  ${REL_NUM}
change_jar_version  cbl_collator_so                  jar  ${BLD_NUM}  ${REL_NUM}  NO_POM
change_jar_version  couchbase-lite-android-javadocs-${EDITION}  jar  ${BLD_NUM}  ${REL_NUM}  NO_POM  "_"
change_jar_version  couchbase-lite-android-source    jar  ${BLD_NUM}  ${REL_NUM}  NO_POM  "_"

zip  -r            ${AND_ZIP_DST}     ${DST_ROOTDIR}

echo ============================================  uploading ${PKG_DEST}/${AND_ZIP_DST}
${PUT_CMD}  ${ANDROID_JAR_DIR}/${AND_ZIP_DST}                ${PKG_DEST}/${AND_ZIP_DST}

echo ============================================  prepare buckets
                              prepare_bucket ${REPOURL}/${GRP_URL}
for J in ${LIST_OF_JARS} ; do prepare_bucket ${REPOURL}/${GRP_URL}/${J} ; prepare_bucket ${REPOURL}/${GRP_URL}/${J}/${REL_NUM} ; done

cd ${ANDROID_JAR_DIR}
echo ============================================  upload to maven repository

upload_new_package  couchbase-lite-android           aar  ${REL_NUM}
upload_new_package  couchbase-lite-java-core         jar  ${REL_NUM}
upload_new_package  couchbase-lite-java-javascript   jar  ${REL_NUM}
upload_new_package  couchbase-lite-java-listener     jar  ${REL_NUM}

echo ============================================ `date`
