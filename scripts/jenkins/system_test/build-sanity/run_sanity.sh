#!/bin/bash

read -a node_list <<< $NODE_IPS
num_nodes=${#node_list[@]}

USER=root
PASSWORD=couchbase
if [ "$DISTRO" = "win64" ]; then
    USER=Administrator
    PASSWORD=Membase123
fi

if [ $num_nodes -ne 1 -a $num_nodes -ne 4 ]; then
    echo "Supports only a sigle node or 4 node runs"
    exit 1
fi


TR_CONF="conf/py-1node-sanity.conf"
NODE_1=${node_list[0]}
if [ $num_nodes -eq 4 ]; then
    NODE_2=${node_list[1]}
    NODE_3=${node_list[2]}
    NODE_4=${node_list[3]}
    TR_CONF="conf/py-4node-sanity.conf"
fi

echo "[global]
username:${USER}
password:${PASSWORD}

[membase]
rest_username:Administrator
rest_password:password

[_1]
ip:${NODE_1}
port:8091
n1ql_port:8093
index_port:9102
services:kv,index,n1ql
" > node_conf.ini

if [ $num_nodes -eq 1 ]; then
echo "[servers]
1:_1
" >> node_conf.ini

else

echo "[cluster1]
1:_1
2:_2

[cluster2]
1:_3
2:_4

[servers]
1:_1
2:_2
3:_3
4:_4

[_2]
ip:${NODE_2}
port:8091

[_3]
ip:${NODE_3}
port:8091

[_4]
ip:${NODE_4}
port:8091
" >> node_conf.ini

fi

version_number=${VERSION}-${CURRENT_BUILD_NUMBER}
echo version=${version_number}

PARAMS="version=${version_number},product=cb,parallel=True"
if [ "x${BIN_URL}" != "x" ]; then
  PARAMS="${PARAMS},url=$BIN_URL"
fi

COUCHBASE_NUM_VBUCKETS=64 python scripts/install.py -i node_conf.ini -p $PARAMS
python testrunner.py -i node_conf.ini -c $TR_CONF -p get-cbcollect-info=True
