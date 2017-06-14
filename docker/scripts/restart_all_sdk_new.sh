#!/bin/sh

cd `dirname $0`

# New hostness Watson docker containers (currently hosted on mega3)
./restart_jenkinsdocker.py couchbase/centos-72-java-sdk:20170613 java-sdk-centos-72 6001 server.jenkins.couchbase.com

wait
echo "All done!"
