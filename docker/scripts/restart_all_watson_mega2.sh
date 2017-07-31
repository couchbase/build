#!/bin/sh

cd `dirname $0`

# New hostness Watson docker containers (currently hosted on mega2)
./restart_jenkinsdocker.py ceejatec/ubuntu-1404-couchbase-build:20170522 watson-ubuntu14.04 5226 server.jenkins.couchbase.com
# Spock Ubuntu 16.04 builder - using CV image because that helps some
# cbdeps builds, notably jemalloc needing valgrind headers
./restart_jenkinsdocker.py ceejatec/ubuntu-1604-couchbase-cv:20170522 spock-ubuntu16.04 5238 server.jenkins.couchbase.com
# Spock Debian 9.1 builder
./restart_jenkinsdocker.py ceejatec/debian-9-couchbase-build:20170731 spock-debian9 5230 server.jenkins.couchbase.com

wait
echo "All done!"

