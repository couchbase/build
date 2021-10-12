#!/bin/bash -ex

# virtualenv stuff
export LC_ALL=C
pip3 install --user --upgrade virtualenv

# start virtualenv
/home/couchbase/.local/bin/virtualenv CBL_DOCS
source ./CBL_DOCS/bin/activate

#Download doc files from packages.couchbase.com
#then upload to docs.couchbase.com

function publish {

    echo "Publish ${PKG}..."
    #Download zip or jar files
    curl --show-error --fail ${S3_URL_PACKAGES}/${PKG}.${EXT} -o ${PKG}.zip
    unzip ${PKG}.zip -d ${PKG}

    #Sync individual files to s3
    echo "Publish ${PKG} to S3 ..."
    aws s3 sync ${PKG}/ ${S3_URL_DOC}/ --acl public-read
    aws s3 ls ${S3_URL_DOC} --human-readable

    pushd ${PKG}/
    CSS_FILES=$(find . -type f -name *.css |sed 's|^./||')
    for fl in ${CSS_FILES}; do
        aws s3 cp --content-type "text/css" $fl ${S3_URL_DOC}/$fl --acl public-read
    done
    popd

    #clean up temp file and directory
    rm -rf ${PKG} ${PKG}.zip
}

# Publish to s3
S3_URL_PACKAGES="http://packages.couchbase.com/releases/${PRODUCT}/${VERSION}"
case ${PRODUCT} in
    "couchbase-lite-ios")
        declare -A PACKAGE_ARRAY
        PACKAGE_ARRAY["couchbase-lite-objc-documentation_enterprise_${VERSION}"]=couchbase-lite-objc
        PACKAGE_ARRAY["couchbase-lite-swift-documentation_enterprise_${VERSION}"]=couchbase-lite-swift
        EXT="zip"
        for PKG in ${!PACKAGE_ARRAY[@]}; do
            S3_URL_DOC="s3://docs.couchbase.com/mobile/${VERSION}/${PACKAGE_ARRAY[${PKG}]}"
            echo "Publishing $PKG to $S3_URL_DOC"
            publish
        done
        ;;
    "couchbase-lite-android" | "couchbase-lite-java")
        declare -A PACKAGE_ARRAY
        PACKAGE_ARRAY["${PRODUCT}-ee-${VERSION}-javadoc"]=${PRODUCT}-ee
        PACKAGE_ARRAY["${PRODUCT}-ee-ktx-${VERSION}-javadoc"]=${PRODUCT}-ktx-ee
        PACKAGE_ARRAY["${PRODUCT}-${VERSION}-javadoc"]=${PRODUCT}
        PACKAGE_ARRAY["${PRODUCT}-ktx-${VERSION}-javadoc"]=${PRODUCT}-ktx
        EXT="jar"
        for PKG in ${!PACKAGE_ARRAY[@]}; do
            S3_URL_DOC="s3://docs.couchbase.com/mobile/${VERSION}/${PACKAGE_ARRAY[${PKG}]}"
            echo "Publishing $PKG to $S3_URL_DOC"
            publish
        done
        ;;
    "couchbase-lite-net")
        EXT="zip"
        PKG="${PRODUCT}-${VERSION}-doc"
        S3_URL_DOC="s3://docs.couchbase.com/mobile/${VERSION}/${PRODUCT}"
        echo "Publishing $PKG to $S3_URL_DOC"
        publish
        ;;
    "couchbase-lite-c")
        EXT="zip"
        PKG="${PRODUCT}-${VERSION}-doc"
        S3_URL_DOC="s3://docs.couchbase.com/mobile/${VERSION}/${PRODUCT}"
        echo "Publishing $PKG to $S3_URL_DOC"
        publish
        ;;
esac

# deactivate virtualenv
echo "Deactivating virtualenv ..."
deactivate
echo
