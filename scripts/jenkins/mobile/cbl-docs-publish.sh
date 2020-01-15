#!/bin/bash

# virtualenv stuff
export LC_ALL=C
pip3 install --user --upgrade virtualenv

# start virtualenv
/home/couchbase/.local/bin/virtualenv CBL_DOCS  || exit 1
source ./CBL_DOCS/bin/activate  || exit 1

S3CONFIG=${HOME}/.ssh/live.s3cfg

# Getting documentation from packages.couchbase.com
S3_URL="http://packages.couchbase.com/releases/${PRODUCT}/${VERSION}"
if [[ ${PRODUCT} == 'couchbase-lite-ios' ]]; then
    PACKAGE_NAME_ARRAY=("couchbase-lite-objc-documentation_enterprise_${VERSION}.zip" "couchbase-lite-swift-documentation_enterprise_${VERSION}.zip")
elif [[ ${PRODUCT} == 'couchbase-lite-android-ee' ]]; then
    PACKAGE_NAME_ARRAY=("${PRODUCT}-${VERSION}-javadoc.jar")
elif [[ ${PRODUCT} == 'couchbase-lite-java' ]]; then
    PACKAGE_NAME_ARRAY=("${PRODUCT}-ee-${VERSION}-javadoc.jar")
fi

echo "Publish to S3 ..."
# Upload to S3 docs.couchbase.com
for PKG in ${PACKAGE_NAME_ARRAY[@]}; do
    echo "Publish ${PKG} to S3 ..."
    PKG_NAME=${PKG%.*} # remove file extentions as directory name
    #S3_URL_couchbase_lite_java="s3://docs.couchbase.com/mobile/${VERSION}/couchbase-lite-java"
    if [[ ${PRODUCT} == 'couchbase-lite-android-ee' ]]; then
        S3_URL_couchbase_lite_android="s3://docs.couchbase.com/mobile/${VERSION}/couchbase-lite-android"
        curl ${S3_URL}/${PKG} -o CouchbaseLite-${VERSION}-javadoc.zip || exit 1
        unzip CouchbaseLite-${VERSION}-javadoc.zip -d CouchbaseLite-${VERSION}-javadoc || exit 1
        #Android:
        s3cmd -c $S3CONFIG --acl-public -r put CouchbaseLite-${VERSION}-javadoc/ ${S3_URL_couchbase_lite_android}/ || exit 1
        s3cmd -c $S3CONFIG ls ${S3_URL_couchbase_lite_android}/
        echo "Re-uploading css file ..."
        pushd CouchbaseLite-${VERSION}-javadoc/
        CSS_FILES=$(find . -type f -name *.css |sed 's|^./||')
        for fl in ${CSS_FILES}; do
            s3cmd -c $S3CONFIG --acl-public put -m "text/css" $fl ${S3_URL_couchbase_lite_android}/$fl
        done
        popd
    elif [[ ${PRODUCT} == 'couchbase-lite-java' ]]; then
        S3_URL_couchbase_lite_java="s3://docs.couchbase.com/mobile/${VERSION}/couchbase-lite-java"
        curl ${S3_URL}/${PKG} -o CouchbaseLite-${VERSION}-javadoc.zip || exit 1
        unzip CouchbaseLite-${VERSION}-javadoc.zip -d CouchbaseLite-${VERSION}-javadoc || exit 1
        s3cmd -c $S3CONFIG --acl-public -r put CouchbaseLite-${VERSION}-javadoc/ ${S3_URL_couchbase_lite_java}/ || exit 1
        s3cmd -c $S3CONFIG ls ${S3_URL_couchbase_lite_java}/
        echo "Re-uploading css file ..."
        pushd CouchbaseLite-${VERSION}-javadoc/
        CSS_FILES=$(find . -type f -name *.css |sed 's|^./||')
        for fl in ${CSS_FILES}; do
            s3cmd -c $S3CONFIG --acl-public put -m "text/css" $fl ${S3_URL_couchbase_lite_java}/$fl
        done
        popd
    elif [[ ${PKG} == "couchbase-lite-objc-documentation_enterprise_${VERSION}.zip" ]]; then
        S3_URL_couchbase_lite_objc="s3://docs.couchbase.com/mobile/${VERSION}/couchbase-lite-objc"
        curl -LO ${S3_URL}/${PKG} || exit 1
        unzip ${PKG} -d ${PKG_NAME} || exit 1
        # Objective-C:
        s3cmd -c $S3CONFIG --acl-public -r put couchbase-lite-objc-documentation_enterprise_${VERSION}/  ${S3_URL_couchbase_lite_objc}/  || exit 1
        s3cmd -c $S3CONFIG ls ${S3_URL_couchbase_lite_objc}/
        echo "Re-uploading css file ..."
        pushd couchbase-lite-objc-documentation_enterprise_${VERSION}/
        CSS_FILES=$(find . -type f -name *.css |sed 's|^./||')
        for fl in ${CSS_FILES}; do
            s3cmd -c $S3CONFIG --acl-public put -m "text/css" $fl ${S3_URL_couchbase_lite_objc}/$fl
        done
        popd
    elif [[ ${PKG} == "couchbase-lite-swift-documentation_enterprise_${VERSION}.zip" ]]; then
        S3_URL_couchbase_lite_swift="s3://docs.couchbase.com/mobile/${VERSION}/couchbase-lite-swift"
        curl -LO ${S3_URL}/${PKG} || exit 1
        unzip ${PKG} -d ${PKG_NAME} || exit 1
        #Swift:
        s3cmd -c $S3CONFIG --acl-public -r put couchbase-lite-swift-documentation_enterprise_${VERSION}/ ${S3_URL_couchbase_lite_swift}/  || exit 1
        s3cmd -c $S3CONFIG ls ${S3_URL_couchbase_lite_swift}/
        echo "Re-uploading css file ..."
        pushd couchbase-lite-swift-documentation_enterprise_${VERSION}/
        CSS_FILES=$(find . -type f -name *.css |sed 's|^./||')
            for fl in ${CSS_FILES}; do
                s3cmd -c $S3CONFIG --acl-public put -m "text/css" $fl ${S3_URL_couchbase_lite_swift}/$fl
            done
        popd
    fi
done

# deactivate virtualenv
echo "Deactivating virtualenv ..."
deactivate
echo

