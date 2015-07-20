#!/bin/bash

python -mplatform | grep -i ubuntu > /dev/null 2>&1
ret=$?
if [ $ret -eq 0 ];then
    echo Building on Ubuntu
    build/scripts/release/linux_repo/couchbase-release/build_deb.sh
    exit 0
fi

python -mplatform | grep -i centos > /dev/null 2>&1
ret=$?
if [ $ret -eq 0 ];then
    echo Building on Centos
    build/scripts/release/linux_repo/couchbase-release/build_rpm.sh
    exit 0
fi
