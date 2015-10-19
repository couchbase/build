#!/bin/bash

docker run -d -p 8091:8091 -v /home/couchbase/buildboard_couchbase:/opt/couchbase/var \
   --ulimit nofile=40960:40960 --ulimit core=100000000:100000000 --ulimit memlock=100000000:100000000 \
   --memory="10g" \
   --name=buildboard-couchbase-server \
   couchbase/server:enterprise-4.0.0-rc0 

docker run -p 2300:22 -d -p 8081:8081 \
    --link=buildboard-couchbase-server:buildboard-couchbase-server \
	--volume=/home/couchbase/build/buildboard:/home/couchbase/buildboard:rw \
	--volume=/home/couchbase/build/buildboard/html:/var/www/html \
	--name="buildboard" \
	mkwok/centos-65-buildboard:20150922
