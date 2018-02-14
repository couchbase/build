#!/bin/bash

container_name="mobile-sgw-ubuntu14"
container=$(docker ps | grep $container_name | awk -F\" '{ print $1 }')
echo "container: $container"
if [[ $container ]]
then
    echo "docker rm -f $container_name"
    docker rm -f $container_name
fi

# Port number 23xx used by SGW
docker run --name=$container_name -v /home/couchbase/jenkinsdocker-ssh:/ssh \
        --volume=/home/couchbase/latestbuilds:/latestbuilds \
        -p 2321:22 -d ceejatec/ubuntu1404-sgw-build:20180214
