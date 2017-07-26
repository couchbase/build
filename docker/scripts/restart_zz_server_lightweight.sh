#!/bin/sh

cd `dirname $0`

# Primary zz-server-lightweight running on mega2 (same port as backup on mega3)
./restart_jenkinsdocker.py ceejatec/ubuntu-1604-couchbase-build:latest zz-server-lightweight 5322 server.jenkins.couchbase.com
echo "All done!"

