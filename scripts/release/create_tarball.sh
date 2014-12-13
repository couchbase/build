#!/bin/bash

RELEASE=$1

mkdir /tmp/couchbase-server_$RELEASE
cd /tmp/couchbase-server_$RELEASE
repo init -u http://github.com/couchbase/manifest -m released/$RELEASE.xml --reference=/home/ceej/co/reporef
repo sync --jobs=6
rm -rf .repo **/.git gperftools icu4c otp pysqlite python-snappy snappy v8
cd ..
tar cvzf couchbase-server_$RELEASE-src.tgz couchbase-server_$RELEASE
