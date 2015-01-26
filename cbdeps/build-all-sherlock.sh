#! /bin/bash
#
# This script builds all of the dependencies in sherlock with their
# "correct" versions. "unfortunately" the versions that the server
# really use is stored in "tlm/deps/manifest.cmake" so it _might_ be
# that the version number there differs from what's stored in this
# file.
#

JEMALLOC_VERSION=5d9732f-cb4
BREAKPAD_VERSION=1e455b5-cb5
LIBEVENT_VERSION=2.0.21-cb1
CURL_VERSION=7.39.0-cb1
SNAPPY_VERSION=1.1.1-cb1
V8_VERSION=e24973a-cb1
ICU4C_VERSION=263593-cb3
ERLANG_VERSION=mb11917-cb5

# In order to use this script you should just create a "build" directory,
# and start building the dependencies like:
#
# trond@ok compile> mkdir obj && cd obj
# trond@ok compile/obj> ../build/cbdeps/build-all-sherlock.sh
#
# You should now be able to copy all of the prebuilt dependencies from
# the "output" subdirectory.
#
# Please note that the script will only try to build dependencies that
# isn't already present, so if you try to run the script twice it'll
# skip everything it'll find a subdirectory for. This means that if you'd
# like to build everything but jemalloc, you can just create a directory
# named jemalloc before invoking the script.
#

export LC_ALL=C
cwd=`pwd`
cd `dirname $0`
root=`pwd`
cd $cwd
platform=`uname -s`
set -e

mkdir -p output

build() {
    name=$1
    version=$2
    if [ -d ${name} ]
    then
        echo "Skipping ${name} (already built)"
    else
        mkdir ${name}
        pushd ${name}
        cmake -D DEP_VERSION=${version} ${root}/${name}
        make
        cp output/${name}/${version}/${name}-*-${version}.* ../output/
        popd
    fi
}

build jemalloc ${JEMALLOC_VERSION}
build breakpad ${BREAKPAD_VERSION}
build libevent ${LIBEVENT_VERSION}
build curl ${CURL_VERSION}
build snappy ${SNAPPY_VERSION}
build v8 ${V8_VERSION}
build icu4c ${ICU4C_VERSION}
build erlang ${ERLANG_VERSION}

pushd output > /dev/zero
for f in *md5
do
   echo $f | sed -e s,.md5,, | awk -F - '{ printf("DECLARE_DEP(%s VERSION %s-%s PLATFORMS %s)\n", $1, $4, $5, $2);}'
done > manifest.cmake
popd > /dev/zero
echo "Created manifest at output/manifest.cmake"
