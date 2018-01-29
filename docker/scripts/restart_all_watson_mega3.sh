#!/bin/sh

cd `dirname $0`

# New hostness Watson docker containers (currently hosted on mega3)
./restart_jenkinsdocker.py ceejatec/centos-65-couchbase-build:20170522 watson-centos6-01 5222 server.jenkins.couchbase.com
# Vulcan CentOS 6 builder
./restart_jenkinsdocker.py ceejatec/centos-69-couchbase-build:20171211 vulcan-centos6 5225 server.jenkins.couchbase.com
./restart_jenkinsdocker.py ceejatec/ubuntu-1604-couchbase-build:20180129 zz-server-lightweight-backup 5322 server.jenkins.couchbase.com
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:20151223 watson-ubuntu12.04 5223 server.jenkins.couchbase.com
./restart_jenkinsdocker.py ceejatec/debian-7-couchbase-build:20170522 watson-debian7 5224 server.jenkins.couchbase.com
./restart_jenkinsdocker.py ceejatec/centos-70-couchbase-build:20170522 watson-centos7-01 5227 server.jenkins.couchbase.com
# Vulcan CentOS 7 builder
./restart_jenkinsdocker.py ceejatec/centos-74-couchbase-build:20171206 vulcan-centos7 5228 server.jenkins.couchbase.com
./restart_jenkinsdocker.py ceejatec/debian-8-couchbase-build:20171106 watson-debian8 5229 server.jenkins.couchbase.com
# Vulcan Debian 8.2 builder
./restart_jenkinsdocker.py ceejatec/debian-8-couchbase-build:20171130 vulcan-debian8 5230 server.jenkins.couchbase.com

# Temporary cbdeps slave based on Ubuntu 12.04 CV image
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-cv:20160304 watson-ubuntu12.04-cv 5233 server.jenkins.couchbase.com

wait
echo "All done!"

