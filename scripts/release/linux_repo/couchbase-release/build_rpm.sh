#!/bin/bash
thisdir=`dirname $0`

rm -rf ~/rpmbuild
mkdir ~/rpmbuild
for x in BUILD BUILDROOT RPMS SOURCES SPECS SRPMS; do mkdir ~/rpmbuild/$x; done

pushd ${thisdir}/rpm

cp -p ../GPG-KEY-COUCHBASE-1.0 ~/rpmbuild/SOURCES
cp -p *.repo ~/rpmbuild/SOURCES
rpmbuild -bb couchbase-release.spec

popd

cp ~/rpmbuild/RPMS/x86_64/couchbase-release-1.0-0_x86_64.rpm couchbase-release-1.0-0-x86_64.rpm
