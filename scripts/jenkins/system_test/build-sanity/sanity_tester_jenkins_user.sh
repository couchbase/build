# for centos
groupadd jenkins
useradd -g jenkins jenkins
yum -y install java-1.7.0-openjdk && yum clean packages
yum -y install python-devel screen
yum -y install screen
cd /usr/local/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > repo
chmod a+x repo
easy_install paramiko
easy_install httplib2
easy_install requests

yum install -y http://latestbuilds.hq.couchbase.com/couchbase-release/35/couchbase-release-1.0-2-x86_64.rpm
yum install -y libcouchbase2-core libcouchbase-devel libcouchbase2-bin
easy_install couchbase

# 1. copy QAKey to authorized keys
# 2. Copy id_hari (or any other authorized key) to clone from github and udpate .ssh/config to map identiyfile to this file for github.com
