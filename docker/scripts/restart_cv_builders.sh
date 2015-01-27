#!/bin/sh

# New hotness Jenkins docker containers
./restart_jenkinsdocker.py cv centos-65 3222 http://172.23.113.52:8081
./restart_jenkinsdocker.py cv debian-7 3226 http://172.23.113.52:8081
./restart_jenkinsdocker.py cv ubuntu-1204 3225 http://172.23.113.52:8081
./restart_jenkinsdocker.py cv ubuntu-1404 3223 http://172.23.113.52:8081
./restart_jenkinsdocker.py cv ubuntu-1404 3224 http://172.23.113.52:8081 10 cv-zz-lightweight lightweight

# Clean up abandoned images
echo "Done!"
echo
echo "The following cleaning steps may raise errors; this is OK."
docker ps -q -a | xargs docker rm
docker images -q --filter "dangling=true" | xargs docker rmi

