#!/bin/bash

echo "docker stop centos-x64-sgw"
docker stop centos-x64-sgw
echo "docker rm centos-x64-sgw"
docker rm centos-x64-sgw
docker run --name="centos-x64-sgw" -v /home/couchbase/jenkinsdocker-ssh:/ssh -p 2423:22 -d ceejatec/centos-65-sgw-build
