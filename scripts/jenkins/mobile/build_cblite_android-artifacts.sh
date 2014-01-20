#!/bin/bash
#          
#          run by jenkins job 'build_cblite_android-artifacts'
#          
#          with paramters used in this script:
#             
#             UPLOAD_ARTIFACTS        (boolean)
#             UPLOAD_VERSION_CBLITE
#             UPLOAD_VERSION_CBLITE_EKTORP
#             UPLOAD_VERSION_CBLITE_JAVASCRIPT
#             UPLOAD_MAVEN_REPO_URL
#             UPLOAD_USERNAME
#             UPLOAD_PASSWORD
#          
#                UPLOAD_USERNAME, UPLOAD_PASSWORD set in build slave >> couchbaselite-mobile-testing <<
#          
#          called with paramters:  branch_name   (e.g. master, stable)
#                                  version       (e.g. 1.0)
#                                  revision      (e.g. 1.0-1234)
#          
source ~jenkins/.bash_profile
export DISPLAY=:0
set -e

function usage
    {
    echo -e "\nuse:  ${0}   branch_name (master or stable)    release (e.g. 1.0)    revision (e.g. 1.0-1234)\n\n"
    }
if [[ ! ${3} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}
VERSION=${2}
REVISION=${3}

if [[ (${GITSPEC} != master) && (${GITSPEC} != stable) ]] ; then usage ; exit 88 ; fi

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

cd ${WORKSPACE}
echo ============================================  sync couchbase-lite-android
echo ============================================  to ${GITSPEC}

if [[ ! -d couchbase-lite-android ]] ; then git clone https://github.com/couchbase/couchbase-lite-android.git ; fi
cd couchbase-lite-android
git checkout      ${GITSPEC}
git pull  origin  ${GITSPEC}
git pull
git submodule init
git submodule update
git show --stat
echo ============================================


if [[ ${UPLOAD_ARTIFACTS} == true ]]
  then
    export UPLOAD_VERSION_CBLITE=${UPLOAD_VERSION_CBLITE}
    export UPLOAD_VERSION_CBLITE_EKTORP=${UPLOAD_VERSION_CBLITE_EKTORP}
    export UPLOAD_VERSION_CBLITE_JAVASCRIPT=${UPLOAD_VERSION_CBLITE_JAVASCRIPT}
    export UPLOAD_MAVEN_REPO_URL=${UPLOAD_MAVEN_REPO_URL}
    export UPLOAD_USERNAME=${UPLOAD_USERNAME}
    export UPLOAD_PASSWORD=${UPLOAD_PASSWORD}
    #source /Users/couchbase/mavencreds 
    echo ============================================
    env | grep -iv password | grep -iv passwd | sort
    echo ============================================
    
    cd ${WORKSPACE}/couchbase-lite-android/CouchbaseLiteProject
    
    echo "********RUNNING: ./build_android_artifacts.sh  *************"
    VERSION=${VERSION}  REVISION=${REVISION}  ./build_android_artifacts.sh
    
    echo "********RUNNING: ./upload_android_artifacts.sh  *************"
    ./upload_android_artifacts.sh
    
  else
    echo "UPLOAD_ARTIFACTS not set - not uploading artifacts"
fi
