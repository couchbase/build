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

source ~/.bash_profile

cd ${WORKSPACE}                    ; echo ====================================
#--------------------------------------------  sync couchbase-lite-android

if [[ ! -d couchbase-lite-android ]] ; then git clone https://github.com/couchbase/couchbase-lite-android.git ; fi
cd couchbase-lite-android
git pull
git submodule init
git submodule update
git show --stat                    ; echo ====================================


if [[ ${UPLOAD_ARTIFACTS} == true ]]
  then
    export UPLOAD_VERSION_CBLITE=${UPLOAD_VERSION_CBLITE}
    export UPLOAD_VERSION_CBLITE_EKTORP=${UPLOAD_VERSION_CBLITE_EKTORP}
    export UPLOAD_VERSION_CBLITE_JAVASCRIPT=${UPLOAD_VERSION_CBLITE_JAVASCRIPT}
    export UPLOAD_MAVEN_REPO_URL=${UPLOAD_MAVEN_REPO_URL}
    export UPLOAD_USERNAME=${UPLOAD_USERNAME}
    export UPLOAD_PASSWORD=${UPLOAD_PASSWORD}
    #source /Users/couchbase/mavencreds 

    env | grep -iv password | sort ; echo ====================================
    
    cd ${WORKSPACE}/couchbase-lite-android/CouchbaseLiteProject

    echo "********RUNNING: ./upload_android_artifacts.sh  *************"
    ./upload_android_artifacts.sh

    echo "********RUNNING: ./build_android_artifacts.sh  *************"
    ./build_android_artifacts.sh

  else
    echo "UPLOAD_ARTIFACTS not set - not uploading artifacts"
fi
