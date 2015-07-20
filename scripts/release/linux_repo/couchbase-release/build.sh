#!/bin/bash

thisdir=`dirname $0`

python -mplatform | grep -i ubuntu > /dev/null 2>&1
ret=$?
if [ $ret -eq 0 ];then
    echo Building on Ubuntu
    ${thisdir}/build_deb.sh
    exit 0
fi

python -mplatform | grep -i centos > /dev/null 2>&1
ret=$?
if [ $ret -eq 0 ];then
    echo Building on Centos
    ${thisdir}/build_rpm.sh
    exit 0
fi
