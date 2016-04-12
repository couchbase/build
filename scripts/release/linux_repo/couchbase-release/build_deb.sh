#!/bin/bash
thisdir=`dirname $0`
pushd $thisdir

VERSION=1.0-1

sudo rm -rf deb/couchbase-release-$VERSION
cp -rp deb/deb_control_files deb/couchbase-release-$VERSION
sed -e "s/%VERSION%/$VERSION/g" -i deb/couchbase-release-$VERSION/DEBIAN/control
mkdir -p deb/couchbase-release-$VERSION/etc/apt/trusted.gpg.d/
cp -p GPG-KEY-COUCHBASE-1.0 deb/couchbase-release-$VERSION/etc/apt/trusted.gpg.d/
sudo chown -R root.root deb/couchbase-release-$VERSION
dpkg-deb --build deb/couchbase-release-$VERSION/

popd

cp $thisdir/deb/couchbase-release-$VERSION.deb ./couchbase-release-$VERSION-amd64.deb
