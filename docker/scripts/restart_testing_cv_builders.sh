#!/bin/sh

cd `dirname $0`

# Currently these slaves are all hosted on mega2

# testing-cv.jenkins slave
./restart_jenkinsdocker.py ceejatec/ubuntu-1604-couchbase-cv:20170302 zz-testing-cv-lightweight 3500 testing-cv.jenkins.couchbase.com &

sleep 2

./restart_jenkinsdocker.py ceejatec/ubuntu-1604-couchbase-cv:20170302 ubuntu16-cv-01 3501 testing-cv.jenkins.couchbase.com --ccache-dir /home/couchbase/slaves/shared_ccache &

wait
echo "All done!"
exit 0

