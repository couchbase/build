#!/bin/bash -xe

read -a node_list <<< $NODE_IPS
read -a priv_ip_list <<< $PRIV_IPS
num_nodes=${#node_list[@]}
ip0=${node_list[0]}
priv_ip0=${priv_ip_list[0]}

which_rel=$1
WORKSPACE=${WORKSPACE:-/Users/hari/github}
CB_USER=${CBUSER:-Administrator}
CB_PASS=${CBPASS:-password}
NODE_USER=root
NODE_PASS=couchbase

NODE_1=${node_list[0]}
if [ $num_nodes -gt 1 ]; then
    NODE_2=${node_list[1]}
    NODE_3=${node_list[2]}
    NODE_4=${node_list[3]}
fi


need_install=0
for x in ${node_list[@]}; do
    cur_install=$(curl --connect-timeout 10 --silent -X GET http://${x}:8091/pools/default | sed 's|.*,"version":"\([0-9]\.[0-9]\.[0-9]-[0-9]*\)-.*|\1|g')
    if [ "${cur_install}" = "${which_rel}" ]; then
        echo "${which_rel} already installed on ${x}"
    else
        echo "${which_rel} not on ${x}"
        need_install=1
        break
    fi
done

if [ $need_install -eq 0 ]; then
    exit 0
fi

git clone https://github.com/couchbase/testrunner
pushd testrunner


echo "[global]
username:${NODE_USER}
password:${NODE_PASS}
port:8091
index_port:9102

[membase]
rest_username:${CB_USER}
rest_password:${CB_PASS}

[_1]
ip:${NODE_1}
services:kv,index,n1ql
" > node_conf.ini

if [ $num_nodes -eq 1 ]; then
echo "[servers]
1:_1
" >> node_conf.ini

else

echo "[servers]
1:_1
2:_2
3:_3
4:_4

[_2]
ip:${NODE_2}
services:kv

[_3]
ip:${NODE_3}
services:kv

[_4]
ip:${NODE_4}
services:kv
" >> node_conf.ini

fi

echo "NODE CONFIGURATION:"
cat node_conf.ini

# === install couchbase on the nodes
url_param=""
install_params="version=${which_rel},product=cb,vbuckets=64"
if [ "x$BIN_URL" != "x" ]; then
    install_params="${install_params},url=${BIN_URL}"
fi
echo python scripts/install.py -i node_conf.ini -p ${install_params}
python scripts/install.py -i node_conf.ini -p ${install_params}
popd


# ==== setup the cluster
echo curl -v -u ${CB_USER}:${CB_PASS} -X POST http://${ip0}:8091/sampleBuckets/install -d '["beer-sample"]'
curl -v -u ${CB_USER}:${CB_PASS} -X POST http://${ip0}:8091/sampleBuckets/install -d '["beer-sample"]'
sleep 10

echo curl -v -X POST -u ${CB_USER}:${CB_PASS} http://${ip0}:8091/pools/default -d memoryQuota=900 -d indexMemoryQuota=900
curl -v -X POST -u ${CB_USER}:${CB_PASS} http://${ip0}:8091/pools/default -d memoryQuota=900 -d indexMemoryQuota=900
sleep 10

echo curl -v -X POST -u ${CB_USER}:${CB_PASS} -d name=default -d ramQuotaMB=256 -d authType=none -d replicaNumber=1 -d proxyPort=11221 http://${ip0}:8091/pools/default/buckets
curl -v -X POST -u ${CB_USER}:${CB_PASS} -d name=default -d ramQuotaMB=256 -d authType=none -d replicaNumber=1 -d proxyPort=11221 http://${ip0}:8091/pools/default/buckets
echo curl -v -X POST -u ${CB_USER}:${CB_PASS} -d name=default1 -d ramQuotaMB=256 -d authType=none -d replicaNumber=1 -d proxyPort=11222 http://${ip0}:8091/pools/default/buckets
curl -v -X POST -u ${CB_USER}:${CB_PASS} -d name=default1 -d ramQuotaMB=256 -d authType=none -d replicaNumber=1 -d proxyPort=11221 http://${ip0}:8091/pools/default/buckets
sleep 10

for ip in ${priv_ip_list[@]:1}; do
    url="http://${ip0}:8091/controller/addNode"
    echo curl -v -u ${CB_USER}:${CB_PASS} $url -d "hostname=${ip}&user=${CB_USER}&password=${CB_PASS}&services=kv"
    curl -v -u ${CB_USER}:${CB_PASS} $url -d "hostname=${ip}&user=${CB_USER}&password=${CB_PASS}&services=kv"
    sleep 2
done

sleep 10

url="http://${ip0}:8091/controller/rebalance"
kn="knownNodes=ns_1@${priv_ip0}"
for ip in ${priv_ip_list[@]:1}; do
    kn="${kn},ns_1@${ip}"
done
echo curl -v -u ${CB_USER}:${CB_PASS} -X POST $url -d "ejectedNodes=&${kn}"
curl -v -u ${CB_USER}:${CB_PASS} -X POST $url -d "ejectedNodes=&${kn}"

sleep 20
