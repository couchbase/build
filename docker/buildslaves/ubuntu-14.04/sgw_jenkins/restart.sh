#!/bin/bash

echo "docker stop sgw-ubuntu-x64"
docker stop sgw-ubuntu-x64
echo "docker rm sgw-ubuntu-x64"
docker rm sgw-ubuntu-x64

# Port number 23xx used by SGW
docker run --name="sgw-ubuntu-x64" -v /home/couchbase/jenkinsdocker-ssh:/ssh -p 2322:22 -d ceejatec/ubuntu1404-sgw-build:3a1d2.feb19

