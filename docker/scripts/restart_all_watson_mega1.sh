#!/bin/sh

cd `dirname $0`

# Currently these slaves are all hosted on mega1

# Watson docker containers
./restart_jenkinsdocker.py ceejatec/suse-11-couchbase-build:20170522 watson-suse11 5228 server.jenkins.couchbase.com
# Vulcan docker container for SuSE 11
./restart_jenkinsdocker.py ceejatec/suse-11-couchbase-build:20180309 vulcan-suse11 5229 server.jenkins.couchbase.com

# Old-school Sherlock docker containers
#./restart_jenkinsdocker.py ceejatec/centos-65-couchbase-build:20150618 sherlocker-centos6 2222 &
#sleep 5
#./restart_jenkinsdocker.py ceejatec/centos-70-couchbase-build:20150930 sherlocker-centos7 2227 &
#sleep 5
#./restart_jenkinsdocker.py ceejatec/debian-7-couchbase-build:20150927 sherlocker-debian7 2224 &
#sleep 5
#./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:latest zz-lightweight 2223 &
#sleep 5
#./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:20150927 sherlocker-ubuntu12.04-01 2225 &
#sleep 5
#./restart_jenkinsdocker.py ceejatec/ubuntu-1404-couchbase-build:20150927 sherlocker-ubuntu14.04 2226 &
#sleep 5
#./restart_jenkinsdocker.py ceejatec/suse-11-couchbase-build:20150927 sherlocker-suse11 2228 &

wait
echo "All done!"

