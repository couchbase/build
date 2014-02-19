#!/bin/bash
#          
#          run by jenkins job 'ep-engine-gerrit-master.sh'
#          
#
#          use "--legacy" parameter for ep-engine-gerrit-251          
#          triggered on Patchset Creation of repo: ep-engine branch: master

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard

REPODIR="cmake/ep-engine"
if [ "$1" = "--legacy" ]
then
   REPODIR="ep-engine"
fi

echo ============================================ update ep-engine
pushd ${REPODIR} 2>&1 > /dev/null
git fetch ssh://review.couchbase.org:29418/ep-engine $GERRIT_REFSPEC && git checkout FETCH_HEAD

echo ============================================ make
popd 2>&1 > /dev/null
make -j4
echo ============================================ make simple-test
cd testrunner
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true

echo ============================================ `date`
