#!/bin/sh

restart_dock() {
  ./restart_jenkinsdocker.py $1 $2 $3 server.jenkins.couchbase.com
  sleep 2
}

# New hostness Watson docker containers
restart_dock ceejatec/centos-65-couchbase-build:20151201 watson-centos6-01 2222
restart_dock ceejatec/centos-65-couchbase-build:20151201 watson-centos6-02 2232
restart_dock ceejatec/ubuntu-1204-couchbase-build:latest zz-server-lightweight 3322
restart_dock ceejatec/ubuntu-1204-couchbase-build:20151020 watson-ubuntu12.04 2223
restart_dock ceejatec/debian-7-couchbase-build:20151020 watson-debian7 2224
restart_dock ceejatec/ubuntu-1404-couchbase-build:20151020 watson-ubuntu14.04 2226
restart_dock ceejatec/suse-11-couchbase-build:20160125 watson-suse11 2228
restart_dock ceejatec/centos-70-couchbase-build:20151020 watson-centos7-01 2227
restart_dock ceejatec/centos-70-couchbase-build:20151020 watson-centos7-02 2237
restart_dock ceejatec/debian-7-couchbase-build-gcc49:20160125 watson-debian7-gcc49 2238

wait

