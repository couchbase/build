#!/bin/bash

container_name=("buildboard") 

for name in "${container_name[@]}"
    do
      container=$(docker ps -a | grep $name | awk -F\" '{ print $1 }')
      echo $container
      if [[ $container ]]
      then
          echo "Removing Docker container $container_name"
          docker rm -f $container_name
      fi
done

docker run -p 2300:22 -d -p 8081:8081 -p 8082:8082 \
    --link=buildboard-db:buildboard-db \
	--volume=/home/couchbase/build/buildboard:/home/couchbase/buildboard:rw \
	--volume=/home/couchbase/build/buildboard/html:/var/www/html \
	--name="buildboard" \
	mkwok/centos-buildboard:20160825
