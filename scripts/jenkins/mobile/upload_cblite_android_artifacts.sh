#!/bin/bash
#          
#          run from manual jobs:   upload_cblite_android_artifacts_master
#                                  upload_cblite_android_artifacts_100
#          
#           to download an android ZIP file,
#              rename the cblite JARs inside,
#              rename the ZIP file and upload it to cbfs,
#              and upload the cblite JARS to our maven repository.
#          
#          called with paramters:
#            branch name          master, release/1.0.0, etc.
#            BLD_TO_RELEASE       number of ZIP file to download (0.0.0-1234)
#            RELEASE_NUMBER       number/name to release as      (0.0.0, 0.0.0-beta)
#          
source ~jenkins/.bash_profile
export DISPLAY=:0
set -e

function usage
    {
    echo -e "\nuse:  ${0}   branch  bld_to_release  release_number \n\n"
    }
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
BLD_TO_RELEASE=${2}

if [[ ${BLD_TO_RELEASE} =~ '([0-9.]*)' ]] ; then RELEASE=${BASH_REMATCH[1]} ; else RELEASE=${BLD_TO_RELEASE} ; fi

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
RELEASE_NUMBER=${3}

CBFS_URL=http://cbfs.hq.couchbase.com:8484/builds

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

cd ${WORKSPACE}

AND_ZIP_SRC=cblite_android_${BLD_TO_RELEASE}.zip
AND_ZIP_DST=cblite_android_${BLD_TO_RELEASE}.zip

ZIP_SRC_DIR=com.couchbase.cblite-${RELEASE}
ZIP_DST_DIR=com.couchbase.cblite-${RELEASE_NUMBER}

echo ============================================  download ${CBFS_URL}/${AND_ZIP_SRC}

wget  --no-verbose  ${CBFS_URL}/${AND_ZIP_SRC}
unzip ${AND_ZIP_SRC}

echo ============================================  renumber to ${AND_ZIP_DST}
mv ${ZIP_SRC_DIR}  ${ZIP_DST_DIR}
cd                 ${ZIP_DST_DIR}
mv  couchbase-lite-java-android-${BLD_TO_RELEASE}.jar     couchbase-lite-java-android-${RELEASE_NUMBER}.jar
mv  couchbase-lite-java-core-${BLD_TO_RELEASE}.jar        couchbase-lite-java-core-${RELEASE_NUMBER}.jar
mv  couchbase-lite-java-javascript-${BLD_TO_RELEASE}.jar  couchbase-lite-java-javascript-${RELEASE_NUMBER}.jar
mv  couchbase-lite-java-listener-${BLD_TO_RELEASE}.jar    couchbase-lite-java-listener-${RELEASE_NUMBER}.jar

cd                 ${WORKSPACE}
zip  -r            ${AND_ZIP_DST}  ${ZIP_DST_DIR}

echo ============================================  upload ${CBFS_URL}/${AND_ZIP_DST}
curl -XPUT --data-binary @${WORKSPACE}/${AND_ZIP_DST} ${CBFS_URL}/${AND_ZIP_DST}


cd                 ${WORKSPACE}
echo ============================================  sync couchbase-lite-android-liteserv
echo ============================================  to ${GITSPEC}

if [[ ! -d couchbase-lite-android-liteserv ]] ; then git clone https://github.com/couchbase/couchbase-lite-android-liteserv.git ; fi
cd         couchbase-lite-android-liteserv
git checkout      ${GITSPEC}
git pull  origin  ${GITSPEC}

SETTINGS=${WORKSPACE}/couchbase-lite-android-liteserv/release/settings.xml
POM_FILE=${WORKSPACE}/couchbase-lite-android-liteserv/release/pom.xml

cd ${ZIP_DST_DIR}
echo ============================================  upload to maven repository
for J in                        \
    couchbase-lite-java-android  \
    couchbase-lite-java-core      \
    couchbase-lite-java-javascript \
    couchbase-lite-java-listener
  do
    JARFILE=${J}-${RELEASE_NUMBER}.jar
    echo "UPLOADING ${J} to .... maven repo:  ${UPLOAD_MAVEN_REPO_URL}"
    mvn --pom ${POM_FILE}                \
        --settings ${SETTINGS} -X        \
        deploy:deploy-file               \
        -Durl=${UPLOAD_MAVEN_REPO_URL}   \
        -DrepositoryId=${REPO_ID}        \
        -Dfile=${JARFILE}                \
        -DuniqueVersion=false            \
        -DgeneratePom=true               \
        -DgroupId=com.couchbase.cblite   \
        -DartifactId=${J}                \
        -Dversion=${RELEASE_NUMBER}      \
        -Dpackaging=jar                   
    fi
  done

echo ============================================ `date`
