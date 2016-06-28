#!/bin/sh

cd `dirname $0`

# Currently these slaves are all hosted on mega

# Old-school buildbot docker containers
./restart_builddocker.py ceejatec/ubuntu-1004-couchbase-repodocker:latest ubuntu-x64-1004-repo-builder 2200
./restart_builddocker.py ceejatec/ubuntu-1004-couchbase-builddocker:latest ubuntu-1004-builddocker-01 2202
./restart_builddocker.py ceejatec/ubuntu-1204-couchbase-builddocker:latest ubuntu-1204-builddocker-01 2205
./restart_builddocker.py ceejatec/centos-58-couchbase-builddocker:latest centos-5-builddocker-01 2204
./restart_builddocker.py ceejatec/centos-63-couchbase-builddocker:latest centos-6-builddocker-01 2201
./restart_builddocker.py ceejatec/debian-7-couchbase-builddocker:latest debian-7-builddocker-01 2203
./restart_builddocker.py ceejatec/suse-11-couchbase-builddocker:20150617 suse-11-builddocker-01 2206

# New hotness Jenkins docker containers
./restart_jenkinsdocker.py ceejatec/centos-65-couchbase-build:20150618 sherlocker-centos6 2222 &
sleep 5
./restart_jenkinsdocker.py ceejatec/centos-70-couchbase-build:20150930 sherlocker-centos7 2227 &
sleep 5
./restart_jenkinsdocker.py ceejatec/debian-7-couchbase-build:20150927 sherlocker-debian7 2224 &
sleep 5
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:latest zz-lightweight 2223 &
sleep 5
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:20150927 sherlocker-ubuntu12.04-01 2225 &
sleep 5
./restart_jenkinsdocker.py ceejatec/ubuntu-1404-couchbase-build:20150927 sherlocker-ubuntu14.04 2226 &
sleep 5
./restart_jenkinsdocker.py ceejatec/suse-11-couchbase-build:20150927 sherlocker-suse11 2228 &

wait
echo "All done!"

