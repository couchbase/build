#!/bin/bash
#          
#          run from scripts:   build_cblite_android.sh
#                              upload_cblite_android_artifacts.sh 
#          
#           to upload JAR files into the maven repository.
#          
#          called with paramters:
#          
#            GITSPEC       master, release/1.0.0, etc. of couchbase-lite-android-liteserv to fetch pom.xml and setting.xml
#            JAR_DIR       contains JARs to upload
#            REL_NUM       number/name to release as      (0.0.0, 0.0.0-beta)
#          
#          in an environment with these variables set:
#          
#            MAVEN_UPLOAD_USERNAME
#            MAVEN_UPLOAD_PASSWORD
#          
source ~/.bash_profile
set -e

CURL_CMD="curl --fail --retry 10"

REPO_ID=couchbase.public.repo
GROUPID=com.couchbase.lite
GRP_URL=com/couchbase/lite
REPOURL=http://files.couchbase.com/maven2

MAVEN_UPLOAD_CREDENTS=${MAVEN_UPLOAD_USERNAME}:${MAVEN_UPLOAD_PASSWORD}

LIST_OF_JARS="                \
              couchbase-lite-android         \
              couchbase-lite-java-core       \
              couchbase-lite-java-javascript \
              couchbase-lite-java-listener   \
             "
function usage
    {
    echo -e "\nuse:  ${0}   branch  release_number   dir_with_jars"
    echo -e "\nwill upload these jars:\n" ; for J in ${LIST_OF_JARS} ; do echo "      "$J ; done
    echo -e "\nto maven repo at:  ${REPOURL}"
    echo -e "\nusing repo-id ${REPO_ID}\n\n"
    }
if [[ ! ${1} ]] ; then usage ; echo error 99 ; exit 99 ; fi
GITSPEC=${1}

if [[ ! ${2} ]] ; then usage ; echo error 88 ; exit 88 ; fi
REL_NUM=${2}

if [[ ! ${3} ]] ; then usage ; echo error 77 ; exit 77 ; fi
JAR_DIR=${3}

MAVENDIR=${WORKSPACE}/couchbase-lite-android-liteserv/release
SETTINGS=${MAVENDIR}/settings.xml
POM_FILE=${MAVENDIR}/pom.xml

function prepare_bucket
    {
    NEW_BUCKET=$1
    echo "DEBUG:  preparing bucket..................................  ${NEW_BUCKET}"
    
    if [[     ! `${CURL_CMD} --user ${MAVEN_UPLOAD_CREDENTS} --fail   ${NEW_BUCKET}` ]]
        then
        echo "DEBUG:  creating bucket...............................  ${NEW_BUCKET}"
        ${CURL_CMD}          --user ${MAVEN_UPLOAD_CREDENTS} -XMKCOL  ${NEW_BUCKET}
    fi
    }

############ ############ ############ ############ ############ ############

cd       ${WORKSPACE}
echo ============================================  sync couchbase-lite-android-liteserv
echo ============================================  to ${GITSPEC}

if [[ ! -d couchbase-lite-android-liteserv ]] ; then git clone https://github.com/couchbase/couchbase-lite-android-liteserv.git ; fi
cd         couchbase-lite-android-liteserv
git checkout      ${GITSPEC}
git pull  origin  ${GITSPEC}

echo ============================================  prepare maven buckets
prepare_bucket ${REPOURL}/${GRP_URL}

for J in ${LIST_OF_JARS} ; do prepare_bucket ${REPOURL}/${GRP_URL}/${J} ; prepare_bucket ${REPOURL}/${GRP_URL}/${J}/${REL_NUM} ; done

cd ${JAR_DIR}
echo ============================================  upload to maven repository
for J in ${LIST_OF_JARS}
  do
    JARFILE=${J}-${REL_NUM}.jar
    echo "UPLOADING ${J} to .... maven repo:  ${REPOURL}/${GRP_URL}"
    mvn --file ${POM_FILE}                             \
        --settings ${SETTINGS} -X                      \
        deploy:deploy-file                             \
        -Durl=${REPOURL}                               \
        -DrepositoryId=${REPO_ID}                      \
        -Dfile=${JAR_DIR}/${JARFILE}                   \
        -DuniqueVersion=false                          \
        -DgeneratePom=true                             \
        -DgroupId=${GROUPID}                           \
        -DartifactId=${J}                              \
        -Dversion=${REL_NUM}                           \
        -Dpackaging=jar                                
  done

echo ========= upload-to-maven.sh ===============
echo ============================================

