#!/bin/bash
# Publish built packages from internal maven to release maven repo

function usage {
    echo -e "\nusage: ${0} product release bld_num release_version publish_url repo_id \n\n"
    exit 0
}

if [ "$#" -ne 5 ]; then
    usage
    exit 1
fi

# Global define
PRODUCT=${1}
RELEASE=${2}
BLD_NUM=${3}
RELEASE_VERSION=${4}
PUBLISH_TARGET=${5}

INTERNAL_MAVEN_URL="http://proget.build.couchbase.com/maven2/internalmaven/com/couchbase/lite/${PRODUCT}/${RELEASE}-${BLD_NUM}"
GROUPID='com.couchbase.lite'
POM_FILE='default-pom.xml'

case ${PUBLISH_TARGET} in

  "mobile-maven")
    PUBLISH_URL="https://mobile.maven.couchbase.com/maven2/dev"
    REPOSITORY_ID="releases"
    ;;
  "internal-nexus")
    PUBLISH_URL="http://nexus.build.couchbase.com:8081/nexus/content/repositories/releases"
    REPOSITORY_ID="releases"
    ;;
  "sonatype")
    PUBLISH_URL="https://oss.sonatype.org/service/local/staging/deploy/maven2/"
    REPOSITORY_ID="ossrh"
    ;;
  "*")
    echo "Unknown PUBLISH_TARGET: ${PUBLISH_TARGET}"
    exit
esac


if [[ ! ${PUBLISH_USERNAME} ]] || [[ ! ${PUBLISH_PASSWORD} ]]; then
    echo "Missing required environment vars: PUBLISH_USERNAME, PUBLISH_PASSWORD"
    exit 1
fi

if [[ ! -f 'settings.xml' ]]; then
    echo "Missing required maven's settings.xml file!"
    exit 1
fi


echo "RELEASE_VERSION: $RELEASE_VERSION"

function update_version {
    # Update pom.xml
    echo "Update release version in ${POM_FILE} \n"
    OLD_VERSION="${RELEASE}-${BLD_NUM}"
    sed -i.bak "s#<version>${OLD_VERSION}</version>#<version>${RELEASE_VERSION}</version>#" ${POM_FILE} || exit 1
    diff ${POM_FILE} ${POM_FILE}.bak
}

function get_pkgs_from_internal_maven {
    #files
    local base_fl_name="${PRODUCT}-${RELEASE}-${BLD_NUM}"
    local library_fl="${base_fl_name}.jar"
    local javadoc_fl="${base_fl_name}-javadoc.jar"
    local javasrc_fl="${base_fl_name}-sources.jar"
    local pom_fl="${base_fl_name}.pom"

    $(wget ${INTERNAL_MAVEN_URL}/${library_fl})
    $(wget ${INTERNAL_MAVEN_URL}/${javadoc_fl})
    $(wget ${INTERNAL_MAVEN_URL}/${javasrc_fl})
    $(wget ${INTERNAL_MAVEN_URL}/${pom_fl})

    # Ensure all required pkgs have been downloaded
    if [[ ! -f ${library_fl} ]] && [[ ! -f ${javadoc_fl} ]] && [[ ! -f ${javasrc_fl} ]] && [[ ! -f ${pom_fl} ]]; then
        echo "Cannot retrieve all the required artifacts for publish!"
        exit 1
    fi

    # Avoid confusion in mvn deploy command
    mv ${pom_fl} ${POM_FILE}
}

function maven_deploy {
    local PKG_FILE=$1
    local PKG_TYPE=$2
    local CLASSIFIER=$3
    local ARTIFACT_ID=${PRODUCT}
    local APP_VERSION=${RELEASE_VERSION}
    local MVN_CMD="mvn --settings ./settings.xml -Dpublish.username=${PUBLISH_USERNAME} -Dpublish.password=${PUBLISH_PASSWORD} -DrepositoryId=${REPOSITORY_ID}"

    if [[ ${PKG_FILE} == "${PRODUCT}-${RELEASE}-${BLD_NUM}.jar" ]]; then
        POM_OPTION='-DpomFile='${POM_FILE}
    else
        POM_OPTION='-DgeneratePom=false'
    fi
    if [[ ! -z ${CLASSIFIER} ]]; then
        CLASSIFER_OPTION="-Dclassifier=${CLASSIFIER}"
    else
        CLASSIFER_OPTION=''
    fi

    CMD="${MVN_CMD} gpg:sign-and-deploy-file -Durl=${PUBLISH_URL} -DgroupId=${GROUPID} -DartifactId=${ARTIFACT_ID} -Dversion=${APP_VERSION} -Dfile=./${PKG_FILE} -Dpackaging=${PKG_TYPE} ${CLASSIFER_OPTION} ${POM_OPTION}"
    $CMD || exit $?
}

function usage {
    echo -e "\nusage:  ${0} product  release  bld_num release_version publish_url\n\n"
    exit 0
}

# Main
# wget *.jar and *.pom from lastestbuilds
get_pkgs_from_internal_maven

# file patterns
base_fl_name="${PRODUCT}-${RELEASE}-${BLD_NUM}"
library_fl="${base_fl_name}.jar"
javadoc_fl="${base_fl_name}-javadoc.jar"
javasrc_fl="${base_fl_name}-sources.jar"

RELEASE_FILES=$(ls ${library_fl} ${javadoc_fl} ${javasrc_fl})
echo "${RELEASE_FILES}\n\n"

# Update default-pom.xml with release_version
update_version

# Loop through all files and publish to maven repo with RELEASE_VERSION
for f in ${RELEASE_FILES}; do
    echo "Uploading file: $f "
    if [[ $f == ${javadoc_fl} ]]; then
        classifer='javadoc'
        pkgtype='jar'
    elif [[ $f == ${javasrc_fl} ]]; then
        classifer='sources'
        pkgtype='jar'
    elif [[ $f == ${library_fl} ]]; then
        classifer=''
        pkgtype='jar'
    fi
    maven_deploy $f ${pkgtype} ${classifer}
done
