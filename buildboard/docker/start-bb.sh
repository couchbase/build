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

# NOTE: The image is local to the buildboard VM host ONLY
docker run -p 2300:22 -d -p 8081:8081 -p 8082:8082 \
    --link=buildboard-db:buildboard-db \
	--volume=/home/couchbase/build/buildboard:/home/couchbase/buildboard:rw \
	--volume=/home/couchbase/build/buildboard/html:/var/www/html \
	--volume=/home/couchbase/.githubtoken:/root/.githubtoken \
	--name="$container_name" --restart=unless-stopped \
	centos-buildboard:20170821
