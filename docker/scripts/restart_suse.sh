#!/bin/sh

cd `dirname $0`

# Spock SUSE container (currently hosted on 172.23.113.172)
./restart_jenkinsdocker.py localonly/suse-12-couchbase-build:20170418 spock-suse12 3125 server.jenkins.couchbase.com &
./restart_jenkinsdocker.py localonly/suse-12-couchbase-build:20171205 vulcan-suse12 3126 server.jenkins.couchbase.com &

wait
echo "All done!"

