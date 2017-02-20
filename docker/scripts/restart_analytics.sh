#!/bin/sh

cd `dirname $0`

# Analytics build container (currently hosted on as-cluster)
./restart_jenkinsdocker.py ceejatec/ubuntu-1404-couchbase-build:20170213 analytics-01 2412 server.jenkins.couchbase.com &

wait
echo "All done!"

