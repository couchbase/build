#!/bin/bash
function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

host_ip=$1
if ! valid_ip $host_ip; then
    echo "$host_ip is not a valid ip address"
    exit 1
fi

rm -f sconfig.xml
curl -X GET http://sdkbuilds.couchbase.com/computer/winsdk-aws-01/config.xml -o sconfig.xml
sed -e "s|\(.*<host>\).*\(</host>.*\)|\1$host_ip\2|g" sconfig.xml > sconfig.xml.new
mv sconfig.xml.new sconfig.xml
curl -X POST http://sdkbuilds.couchbase.com/computer/winsdk-aws-01/config.xml --data-binary "@sconfig.xml"
sleep 2
curl -X POST http://sdkbuilds.couchbase.com/computer/winsdk-aws-01/launchSlaveAgent
