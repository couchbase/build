#!/bin/sh

cd `dirname $0`

# SUSE 12 containers (currently hosted on 172.23.96.152)
./restart_jenkinsdocker.py localonly/suse-12-couchbase-build:20170418 spock-suse12 3125 server.jenkins.couchbase.com &
./restart_jenkinsdocker.py localonly/suse-12-couchbase-build:20181126 vulcan-suse12 3126 server.jenkins.couchbase.com &

wait
echo "All done!"

