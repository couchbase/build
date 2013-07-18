#!/bin/sh

CWD=`pwd`
TARGET_BASE=spymemcached
TARGET_DIR=$CWD/docs
BUILD_DIR=$CWD/$TARGET_BASE

cd $BUILD_DIR
git fetch --tags

for tag in `git tag -l`; do 
    cd $BUILD_DIR
    echo "Building from tag $tag"
# Clean the build directory
    ant clean >>/dev/null 2>&1
    git checkout $tag >>/dev/null 2>&1

# Build the documentation
    ant docs >>/dev/null 2>&1

    TARGET_TAG=$TARGET_BASE-$tag

# Clean the previously built files
    rm -rf $TARGET_DIR/$TARGET_TAG
    rm -f $TARGET_DIR/$TARGET_TAG.zip 

# Only build and copy if the docs build was successful

    if [ -d 'build/docs' ]
    then
        mkdir -p $TARGET_DIR/$TARGET_TAG
        cp -r build/docs/* $TARGET_DIR/$TARGET_TAG/

        cd $TARGET_DIR
        zip -r $TARGET_DIR/$TARGET_TAG.zip ./$TARGET_TAG >>/dev/null 2>&1

    fi
done
