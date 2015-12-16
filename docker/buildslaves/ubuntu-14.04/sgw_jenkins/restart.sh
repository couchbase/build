#!/bin/bash

echo "docker stop mobile-sgw-ubuntu14"
docker stop mobile-sgw-ubuntu14 
echo "docker rm mobile-sgw-ubuntu14" 
docker rm mobile-sgw-ubuntu14 

# Port number 23xx used by SGW
docker run --name="mobile-sgw-ubuntu14" -v /home/couchbase/jenkinsdocker-ssh:/ssh -p 2321:22 -d ceejatec/ubuntu1404-sgw-build:20151210

