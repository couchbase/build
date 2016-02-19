#!/bin/bash

git pull https://github.com/couchbase/testrunner

NODE_IP=${CPDSN:-127.0.0.1}
CB_USER=${CPUSER:-Administrator}
CB_PASS=${CPPASS:-password}
NODE_USER=root
NODE_PASS=couchbase

echo "
[global]
username:${NODE_USER}
password:${NODE_PASS}

[membase]
rest_username:${CB_USER}
rest_password:${CB_PASS}

[_1]
ip:${NODE_IP}
port:8091
n1ql_port:8093
index_port:9102
services:kv,index,n1ql

[servers]
1:_1
" > node_conf.ini

# get latest dev version and install
watson_latest_good=$(curl http://server.jenkins.couchbase.com/view/build-sanity/job/build-sanity-watson/lastSuccessfulBuild/artifact/run_details | grep LAST_SUCCESSFUL | awk -F= '{print $2}')
watson_version="4.5.0-${watson_latest_good}"
pushd testrunner
python scripts/install.py -i node_conf.ini -p version=${watson_version},product=cb
popd

# create default bucket
curl -X POST -u ${CB_USER}:${CB_PASS} \
    -d name=default -d ramQuotaMB=1024 -d authType=none \
    -d proxyPort=11216 \
    http://${NODE_IP}:8091/pools/default/buckets
