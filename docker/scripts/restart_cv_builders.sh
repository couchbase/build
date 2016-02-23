#!/bin/sh

./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-cv:20160218 cv-zz-lightweight 3224 cv.jenkins.couchbase.com&
sleep 2
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-cv:20160218 ubuntu12-cv-01 2322 cv.jenkins.couchbase.com &
sleep 2
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-cv:20160218 ubuntu12-cv-02 2323 cv.jenkins.couchbase.com &
sleep 2
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-cv:20160218 ubuntu12-cv-03 2324 cv.jenkins.couchbase.com &
sleep 2
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-cv:20160218 ubuntu12-cv-04 2325 cv.jenkins.couchbase.com &

