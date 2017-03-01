#!/bin/bash -ex

docker network create temp-bbdb

docker run -d \
  -v /home/couchbase/cb-bbdb:/opt/couchbase/var \
  -p 8191-8195:8091-8095 \
  --network=temp-bbdb \
  --name=temp-bbdb-database \
  --restart=unless-stopped \
  couchbase:4.5.1

docker run -d \
  -v /home/couchbase/bbdb:/home/couchbase/bbdb \
  -v /home/couchbase/jenkinsdocker-ssh:/root/.ssh \
  --network=temp-bbdb \
  --name=temp-bbdb-loader \
  --restart=unless-stopped \
  ceejatec/temp-bbdb:20170228

docker run -d \
  -v /home/couchbase/sm:/usr/local/app \
  -p 8181:8181 \
  -p 8282:8282 \
  --network=temp-bbdb \
  --name=temp-restapis \
  --restart=unless-stopped \
  ceejatec/temp-bbdb:20170228 \
  /usr/local/app/bbdb_restapis/start_script.sh

