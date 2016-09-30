#!/bin/sh

cd `dirname $0`

# New hostness Watson docker containers (currently hosted on mega3)
./restart_jenkinsdocker.py ceejatec/centos-65-couchbase-build:20151223 watson-centos6-01 5222 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/centos-65-couchbase-build:20151223 watson-centos6-02 5232 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:latest zz-server-lightweight 5322 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:20151223 watson-ubuntu12.04 5223 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/debian-7-couchbase-build:20160229 watson-debian7 5224 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/ubuntu-1404-couchbase-build:20151223 watson-ubuntu14.04 5226 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/suse-11-couchbase-build:20151223 watson-suse11 5228 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/centos-70-couchbase-build:20151223 watson-centos7-01 5227 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/centos-70-couchbase-build:20151223 watson-centos7-02 5237 server.jenkins.couchbase.com &
sleep 5
./restart_jenkinsdocker.py ceejatec/debian-8-couchbase-build:20160112 watson-debian8 5229 server.jenkins.couchbase.com &

wait
echo "All done!"

