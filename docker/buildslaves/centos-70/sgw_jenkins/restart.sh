#!/bin/bash

container=$(docker ps | grep mobile-sgw-centos7 | awk -F\" '{ print $1 }')
echo "container: $container"
if [[ $container ]] 
then
    echo "docker rm -f mobile-sgw-centos70"
    docker rm -f mobile-sgw-centos70
fi

docker run --name="mobile-sgw-centos70" -v /home/couchbase/jenkinsdocker-ssh:/ssh \
        --volume=/home/couchbase/latestbuilds:/latestbuilds \
        -p 2322:22 -d ceejatec/centos-70-sgw-build:20160512
