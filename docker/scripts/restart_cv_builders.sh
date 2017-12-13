#!/bin/sh

cd `dirname $0`

# Currently these slaves are all hosted on mega2

# cv.jenkins slaves
./restart_jenkinsdocker.py ceejatec/ubuntu-1604-couchbase-build:20171212 cv-zz-lightweight 3224 cv.jenkins.couchbase.com &

# Launch additional CV slaves using Ansible; see cv-ansible/README
#docker run --rm -i -v /home/couchbase/jenkinsdocker-ssh:/home/couchbase/jenkinsdocker-ssh -v `pwd`/cv-ansible:/mnt williamyeh/ansible:ubuntu16.04 /mnt/restart_cv_dockerslaves.sh &

# Factory CV slaves
#./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-cv:20151009 cv-sherlocker-ubuntu12.04-01 2229 &
#sleep 5
#./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-cv:20151009 cv-sherlocker-ubuntu12.04-02 2230 &
#sleep 5
#./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-cv:20151009 cv-sherlocker-ubuntu12.04-03 2231 &
#sleep 5
./restart_jenkinsdocker.py ceejatec/centos-70-couchbase-build:20151223 centos70-cv-build-01 2422 cv.jenkins.couchbase.com --ccache-dir /home/couchbase/slaves/shared_ccache &

wait
echo "All done!"
exit 0

