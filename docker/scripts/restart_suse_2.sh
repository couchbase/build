#!/bin/sh

cd `dirname $0`

# SUSE 12 containers (currently hosted on 172.23.96.156)
./restart_jenkinsdocker.py localonly/suse-12-couchbase-build:20170418 spock-suse12-02 3127 server.jenkins.couchbase.com &
./restart_jenkinsdocker.py localonly/suse-12-couchbase-build:20190425 vulcan-suse12-02 3128 server.jenkins.couchbase.com &

wait
echo "All done!"

