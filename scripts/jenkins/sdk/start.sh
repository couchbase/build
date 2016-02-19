#!/bin/bash

iid=$1
ip=`python sdk_win_instance.py $iid start`
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error starting instance"
    exit 1
fi 

rm -f sconfig.xml
curl -X GET http://sdkbuilds.couchbase.com/computer/winsdk-aws-01/config.xml -o sconfig.xml
sed -e "s|\(.*<host>\).*\(</host>.*\)|\1$ip\2|g" sconfig.xml > sconfig.xml.new
mv sconfig.xml.new sconfig.xml
curl -X POST http://sdkbuilds.couchbase.com/computer/winsdk-aws-01/config.xml --data-binary "@sconfig.xml"
