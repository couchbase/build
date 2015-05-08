#!/bin/bash

rm -rf ~/rpmbuild
mkdir ~/rpmbuild
for x in BUILD BUILDROOT RPMS SOURCES SPECS SRPMS; do mkdir ~/rpmbuild/$x; done

cd rpm

cp -p ../GPG-KEY-COUCHBASE-1.0 ~/rpmbuild/SOURCES
cp -p *.repo ~/rpmbuild/SOURCES
rpmbuild -bb couchbase-release.spec
