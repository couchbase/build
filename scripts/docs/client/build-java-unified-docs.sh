#!/bin/sh

CWD=`pwd`
TARGET_BASE=couchbase-java-client
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

    ant docs 

    if [ -d 'build/docs' ]
    then

# Work out the spymemcached version
        echo "Currently in $BUILD_DIR"
        
        SPYVER=`ls build/ivy/lib/couchbase-client/common/spymemcached-[0-9]*.jar|sed -e "s/.*spymemcached-//"|sed -e "s/\.jar$//"`
        
        echo "Spy version $SPYVER"
        
# Clean the previously built files
        TARGET_TAG=$TARGET_BASE-$tag
        
        rm -rf $TARGET_DIR/$TARGET_TAG
        rm -f $TARGET_DIR/$TARGET_TAG.zip 
        
        cd $CWD/spymemcached
        git checkout $SPYVER
        ant clean
        ant docs
        
        cd $CWD
        
        rm build-classpath.tmp
        find couchbase-java-client/build "*.jar" >>build-classpath.tmp
        find spymemcached/build "*.jar" >>build-classpath.tmp
        
        CLASSPATH=`cat build-classpath.tmp|tr "\n" ":"`
        
        echo CLASSPATH is $CLASSPATH
        
        javadoc -d $TARGET_DIR/$TARGET_TAG -author -version -use -windowtitle "couchbase-client $tag API" -doctitle "couchbase-client $tag API" -bottom "Copyright &copy; 2006-2009 Dustin Sallings, 2009-2012 Couchbase, Inc." -classpath $CLASSPATH `find couchbase-java-client/src/main/java/com/couchbase/client -name "*.java"` `find spymemcached/src/main/java/net/spy/memcached -name "*.java"`
        
        cd $TARGET_DIR
        zip -r $TARGET_DIR/$TARGET_TAG.zip ./$TARGET_TAG >>/dev/null 2>&1
    fi

done
