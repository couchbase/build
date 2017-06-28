#!/bin/bash -ex

mkdir -p build artifacts

pushd couchbase-lite-core
VER=$(git rev-parse --verify HEAD)
popd

echo @@@@@@@@@@@@@@@@
echo building.....
echo @@@@@@@@@@@@@@@@
pushd build
cmake -D LITECORE_BUILD_SQLITE=1 ..
make -j4 install
popd

echo @@@@@@@@@@@@@@@@
echo zipping artifacts...
echo @@@@@@@@@@@@@@@@
pushd install
tar czf ../artifacts/couchbase-lite-core-${VER}.tar.gz *

echo @@@@@@@@@@@@@@@@
echo Done
echo @@@@@@@@@@@@@@@@
