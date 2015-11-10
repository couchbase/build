#!/bin/bash

install_only="no"
if [ "$1" = "-i" ]; then
    install_only="yes"
fi

read -a node_list <<< $NODE_IPS
num_nodes=${#node_list[@]}

USER=root
PASSWORD=couchbase

TR_CONF="conf/py-1node-sanity.conf"
NODE_1=${node_list[0]}
if [ $num_nodes -gt 1 ]; then
    TR_CONF="conf/py-multi-node-sanity.conf"
    NODE_2=${node_list[1]}
    NODE_3=${node_list[2]}
    NODE_4=${node_list[3]}
fi

if [ "$DISTRO" = "macos" ]; then
    USER=couchbase
    if [ $num_nodes -gt 1 ]; then
        TR_CONF="conf/py-mac-sanity.conf"
    fi
elif [ "$DISTRO" = "win64" ]; then
    USER=Administrator
    PASSWORD=Membase123
fi

if [ -n "${TR_CONF_FILE}" ]; then
    TR_CONF=${TR_CONF_FILE}
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
if [ "$DISTRO" = "macos" ]; then
echo "[cluster1]
1:_1

[cluster2]
1:_2

[servers]
1:_1
2:_2

[_2]
ip:${NODE_2}
port:8091
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
fi


echo "NODE CONFIGURATION:"
cat node_conf.ini

version_number=${VERSION}-${CURRENT_BUILD_NUMBER}
echo version=${version_number}

PARAMS="version=${version_number},product=cb"
if [ "x${BIN_URL}" != "x" ]; then
  PARAMS="${PARAMS},url=$BIN_URL"
fi
if [ "$DISTRO" != "win64" ]; then
    PARAMS="${PARAMS},parallel=True"
fi

echo "Running: COUCHBASE_NUM_VBUCKETS=64 python scripts/install.py -i node_conf.ini -p $PARAMS"
COUCHBASE_NUM_VBUCKETS=64 python scripts/install.py -i node_conf.ini -p $PARAMS
echo

if [ "$install_only" = "yes" ]; then
  exit 0
fi

echo "Running python testrunner.py -i node_conf.ini -c $TR_CONF -p get-cbcollect-info=True"
python testrunner.py -i node_conf.ini -c $TR_CONF -p get-cbcollect-info=True,get-couch-dbinfo=True,skip_cleanup=True
