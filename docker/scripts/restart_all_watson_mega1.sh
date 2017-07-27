#!/bin/sh

cd `dirname $0`

# New hostness Watson docker containers (currently hosted on mega)
./restart_jenkinsdocker.py ceejatec/suse-11-couchbase-build:20170522 watson-suse11 5228 server.jenkins.couchbase.com

wait
echo "All done!"

