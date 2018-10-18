#!/bin/bash -xe

which_rel=$1
NODE_IP=${CPDSN:-127.0.0.1}
CB_USER=${CPUSER:-Administrator}
CB_PASS=${CPPASS:-password}
NODE_USER=root
NODE_PASS=couchbase

# which_rel evaluation -- not fail-proof, but will start with this
if [ "x$which_rel" = "x" ]; then
    which_rel=dev
fi

if [ "x$which_rel" = "dev" ]; then
    # get latest dev version and install
    latest_dev=$(curl http://server.jenkins.couchbase.com/view/build-sanity/job/build-sanity-watson/lastSuccessfulBuild/artifact/run_details | grep LAST_SUCCESSFUL | awk -F= '{print $2}')
    which_rel="4.5.0-${latest_dev}"
fi

cur_install=$(curl --connect-timeout 10 --silent -X GET http://${NODE_IP}:8091/pools/default | sed 's|.*,"version":"\([0-9]\.[0-9]\.[0-9]-[0-9]*\)-.*|\1|g')
if [ "${cur_install}" = "${which_rel}" ]; then
    echo "${which_rel} already installed on ${NODE_IP}"
    exit 0
fi

pushd ${WORKSPACE}/testrunner

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

install_params="version=${which_rel},product=cb,vbuckets=64${INSTALL_PARAMS}"
if [ "x$BIN_URL" != "x" ]; then
    install_params="${install_params},url=${BIN_URL}"
fi
python scripts/install.py -i node_conf.ini -p ${install_params}
popd

curl -i -u ${CB_USER}:${CB_PASS} -X POST http://${NODE_IP}:8091/settings/indexes -d 'storageMode=memory_optimized'

# create default bucket
curl -X POST -u ${CB_USER}:${CB_PASS} \
    -d name=default -d ramQuotaMB=1024 -d authType=none \
    -d proxyPort=11216 \
    http://${NODE_IP}:8091/pools/default/buckets
