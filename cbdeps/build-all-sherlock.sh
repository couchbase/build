#! /bin/bash
#
# This script builds all of the dependencies in sherlock with their
# "correct" versions. "unfortunately" the versions that the server
# really use is stored in "tlm/deps/manifest.cmake" so it _might_ be
# that the version number there differs from what's stored in this
# file.
#

JEMALLOC_VERSION=5d9732f-cb4
BREAKPAD_VERSION=369ec25-cb3
LIBEVENT_VERSION=2.0.21-cb1
CURL_VERSION=7.39.0-cb1
SNAPPY_VERSION=1.1.1-cb1
V8_VERSION=e24973a-cb1

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

if [ -d jemalloc ]
then
   echo "Skipping jemalloc"
else
   mkdir jemalloc
   cd jemalloc
   cmake -D DEP_VERSION=${JEMALLOC_VERSION} ${root}/jemalloc
   make
   cp output/jemalloc/${JEMALLOC_VERSION}/jemalloc-*-${JEMALLOC_VERSION}.* ../output/
   cd ..
fi

if [ "${platform}" = "Linux" ]
then
   if [ -d breakpad ]
   then
      echo "Skipping breakpad"
   else
      mkdir breakpad
      cd breakpad
      cmake -D DEP_VERSION=${BREAKPAD_VERSION} ${root}/breakpad
      make
      cp output/breakpad/${BREAKPAD_VERSION}/breakpad-*-${BREAKPAD_VERSION}.* ../output/
      cd ..
   fi
else
   echo "Skipping breakpad"
fi

if [ -d libevent ]
then
   echo "Skipping libevent"
else
   mkdir libevent
   cd libevent
   cmake -D DEP_VERSION=${LIBEVENT_VERSION} ${root}/libevent
   make
   cp output/libevent/${LIBEVENT_VERSION}/libevent-*-${LIBEVENT_VERSION}.* ../output/
   cd ..
fi

if [ -d curl ]
then
   echo "Skipping cURL"
else
   mkdir curl
   cd curl
   cmake -D DEP_VERSION=${CURL_VERSION} ${root}/curl
   make
   cp output/curl/${CURL_VERSION}/curl-*-${CURL_VERSION}.* ../output/
   cd ..
fi

if [ -d snappy ]
then
   echo "Skipping snappy"
else
   mkdir snappy
   cd snappy
   cmake -D DEP_VERSION=${SNAPPY_VERSION} ${root}/snappy
   make
   cp output/snappy/${SNAPPY_VERSION}/snappy-*-${SNAPPY_VERSION}.* ../output/
   cd ..
fi

if [ -d v8 ]
then
   echo "Skipping V8"
else
   mkdir v8
   cd v8
   cmake -D DEP_VERSION=${V8_VERSION} ${root}/v8
   make
   cp output/v8/${V8_VERSION}/v8-*-${V8_VERSION}.* ../output/
   cd ..
fi
