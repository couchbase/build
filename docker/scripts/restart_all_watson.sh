#!/bin/sh

# New hostness Watson docker containers (currently hosted on mega3)
./restart_jenkinsdocker.py ceejatec/centos-65-couchbase-build:20151223 watson-centos6-01 2222 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/centos-65-couchbase-build:20151223 watson-centos6-02 2232 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:latest zz-server-lightweight 3322 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:20151223 watson-ubuntu12.04 2223 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/debian-7-couchbase-build:20160229 watson-debian7 2224 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/ubuntu-1404-couchbase-build:20151223 watson-ubuntu14.04 2226 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/suse-11-couchbase-build:20151223 watson-suse11 2228 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/centos-70-couchbase-build:20151223 watson-centos7-01 2227 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/centos-70-couchbase-build:20151223 watson-centos7-02 2237 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/debian-8-couchbase-build:20160112 watson-debian8 2229 server.jenkins.couchbase.com &

wait
echo "All done!"

