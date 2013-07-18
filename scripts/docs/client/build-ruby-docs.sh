#!/bin/sh

CWD=`pwd`
TARGET_BASE=couchbase-ruby-client
TARGET_DIR=$CWD/docs
BUILD_DIR=$CWD/$TARGET_BASE

cd $BUILD_DIR
git fetch --tags

for file in `git tag -l`; do 
    cd $BUILD_DIR
    echo "Building from tag $file"
# Clean the build directory
    ant clean >>/dev/null 2>&1
    git checkout $file >>/dev/null 2>&1

# Build the documentation
    ant docs >>/dev/null 2>&1
    BASE_VER=$(git describe)
    yard doc -o $TARGET_DIR/$TARGET_BASE-$BASE_VER

    cd $TARGET_DIR
    zip -r $TARGET_DIR/$TARGET_BASE-$BASE_VER.zip ./$TARGET_BASE-$BASE_VER >>/dev/null 2>&1

done
