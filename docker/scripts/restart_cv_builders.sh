#!/bin/sh

cd `dirname $0`

# Currently these slaves are all hosted on mega2

# cv.jenkins slaves
./restart_jenkinsdocker.py ceejatec/ubuntu-1604-couchbase-build:20180109 cv-zz-lightweight 3224 cv.jenkins.couchbase.com &

wait
echo "All done!"
exit 0

