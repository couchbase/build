#!/bin/sh

# Old-school buildbot docker containers
./restart_builddocker.py ceejatec/ubuntu-1004-couchbase-builddocker:latest ubuntu-1004-builddocker-01 2202
./restart_builddocker.py ceejatec/ubuntu-1204-couchbase-builddocker:latest ubuntu-1204-builddocker-01 2205
./restart_builddocker.py ceejatec/centos-58-couchbase-builddocker:latest centos-5-builddocker-01 2204
./restart_builddocker.py ceejatec/centos-63-couchbase-builddocker:latest centos-6-builddocker-01 2201
./restart_builddocker.py ceejatec/debian-7-couchbase-builddocker:latest debian-7-builddocker-01 2203

# New hotness Jenkins docker containers
./restart_jenkinsdocker.py ceejatec/centos-65-couchbase-build:latest sherlocker-centos6 2222
./restart_jenkinsdocker.py ceejatec/centos-70-couchbase-build:latest sherlocker-centos7 2227
./restart_jenkinsdocker.py ceejatec/debian-7-couchbase-build:latest sherlocker-debian7 2224
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:latest zz-lightweight 2223
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:latest sherlocker-ubuntu12.04-01 2225
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:latest sherlocker-ubuntu12.04-02 2229
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:latest sherlocker-ubuntu12.04-03 2230
./restart_jenkinsdocker.py ceejatec/ubuntu-1404-couchbase-build:latest sherlocker-ubuntu14.04 2226
./restart_jenkinsdocker.py ceejatec/opensuse-113-couchbase-build:latest sherlocker-opensuse11.3 2228

# Clean up abandoned images
echo "Done!"
echo
echo "The following cleaning steps may raise errors; this is OK."
docker ps -q -a | xargs docker rm
docker images -q --filter "dangling=true" | xargs docker rmi

