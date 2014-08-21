#!/bin/sh

./restart_builddocker.py ceejatec/ubuntu-1004-couchbase-builddocker:latest ubuntu-1004-builddocker-01 2202
./restart_builddocker.py ceejatec/ubuntu-1204-couchbase-builddocker:latest ubuntu-1204-builddocker-01 2205
./restart_builddocker.py ceejatec/centos-58-couchbase-builddocker:latest centos-5-builddocker-01 2204
./restart_builddocker.py ceejatec/centos-63-couchbase-builddocker:latest centos-6-builddocker-01 2201
./restart_builddocker.py ceejatec/debian-7-couchbase-builddocker:latest debian-7-builddocker-01 2203

# Clean up abandoned images
echo "Done!"
echo
echo "The following cleaning steps may raise errors; this is OK."
docker ps -q -a | xargs docker rm
docker images -q --filter "dangling=true" | xargs docker rmi

