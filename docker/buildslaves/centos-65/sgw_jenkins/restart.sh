#!/bin/bash

echo "docker stop mobile-sgw-centos65"
docker stop mobile-sgw-centos65
echo "docker rm mobile-sgw-centos65"
docker rm mobile-sgw-centos65
docker run --name="mobile-sgw-centos65" -v /home/couchbase/jenkinsdocker-ssh:/ssh -p 2322:22 -d ceejatec/centos-65-sgw-build:20151210
