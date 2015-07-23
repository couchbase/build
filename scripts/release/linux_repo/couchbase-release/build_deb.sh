#!/bin/bash
thisdir=`dirname $0`
pushd $thisdir

mkdir -p deb/couchbase-release-1.0-0/etc/apt/trusted.gpg.d/
cp -p GPG-KEY-COUCHBASE-1.0 deb/couchbase-release-1.0-0/etc/apt/trusted.gpg.d/
sudo chown -R root.root deb/couchbase-release-1.0-0
dpkg-deb --build deb/couchbase-release-1.0-0/

popd

cp $thisdir/deb/couchbase-release*.deb .
