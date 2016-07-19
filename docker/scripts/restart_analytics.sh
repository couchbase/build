#!/bin/sh

cd `dirname $0`

# Analytics build container (currently hosted on mega3)
./restart_jenkinsdocker.py ceejatec/ubuntu-1404-analytics-build:20160718 analytics-01 2411 server.jenkins.couchbase.com &

wait
echo "All done!"

