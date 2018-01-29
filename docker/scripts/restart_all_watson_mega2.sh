#!/bin/sh

cd `dirname $0`

# New hostness Watson docker containers (currently hosted on mega2)
./restart_jenkinsdocker.py ceejatec/ubuntu-1404-couchbase-build:20170522 watson-ubuntu14.04 5226 server.jenkins.couchbase.com
# Vulcan Ubuntu 14.04 builder
./restart_jenkinsdocker.py ceejatec/ubuntu-1404-couchbase-build:20180109 vulcan-ubuntu14.04 5232 server.jenkins.couchbase.com
# Spock Ubuntu 16.04 builder - using CV image because that helps some
# cbdeps builds, notably jemalloc needing valgrind headers
./restart_jenkinsdocker.py ceejatec/ubuntu-1604-couchbase-cv:20170522 spock-ubuntu16.04 5238 server.jenkins.couchbase.com
# Spock Debian 9.1 builder
./restart_jenkinsdocker.py ceejatec/debian-9-couchbase-build:20170911 spock-debian9 5230 server.jenkins.couchbase.com
# Vulcan Debian 9.1 builder
./restart_jenkinsdocker.py ceejatec/debian-9-couchbase-build:20171130 vulcan-debian9 5231 server.jenkins.couchbase.com
# Vulcan Ubuntu 16.04 slave - probably should use CV image as well,
# but don't want to rebuild that yet
./restart_jenkinsdocker.py ceejatec/ubuntu-1604-couchbase-build:20180129 vulcan-ubuntu16.04 5239 server.jenkins.couchbase.com
# Primary zz-server-lightweight running on mega2 (same port as backup on mega3)
./restart_jenkinsdocker.py ceejatec/ubuntu-1604-couchbase-build:20180129 zz-server-lightweight 5322 server.jenkins.couchbase.com

wait
echo "All done!"

