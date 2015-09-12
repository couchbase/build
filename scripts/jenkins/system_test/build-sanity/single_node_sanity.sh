#!/bin/bash

git clean -dfx
echo "[global]
username:root
password:couchbase

[servers]
1:_1

[_1]
ip:${NODE_IP}
port:8091
n1ql_port:8093
index_port:9102
services:kv,index,n1ql

[membase]
rest_username:Administrator
rest_password:password" > singlenode.ini


version_number=${VERSION}-${CURRENT_BUILD_NUMBER}
echo version=${version_number}

PARAMS="version=${version_number},product=cb"
if [ "x${BIN_URL}" != "x" ]; then
  PARAMS="${PARAMS},url=$BIN_URL"
fi

COUCHBASE_NUM_VBUCKETS=64 python scripts/install.py -i singlenode.ini -p $PARAMS
python testrunner.py -i singlenode.ini -c conf/py-1node-sanity.conf -p get-cbcollect-info=True
