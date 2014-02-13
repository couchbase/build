#!/bin/bash
#          
#          run by jenkins job 'healthchecker-gerrit-master'
#                             healthchecker-gerrit-300
#                             healthchecker-gerrit-250
#          with no paramters
#          
#          triggered on Patchset Creation of repo: healthchecker branch: master

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python >/dev/null || true

git clean -xfd

echo ============================================ update healthchecker, cli, testrunner
if [[ ! -d couchbase-cli ]] ; then git fetch ssh://review.couchbase.org:29418/couchbase-cli $GERRIT_REFSPEC && git checkout FETCH_HEAD ; fi

if [[ ! -d healthchecker ]] ; then git fetch ssh://review.couchbase.org:29418/healthchecker $GERRIT_REFSPEC && git checkout FETCH_HEAD ; fi

if [[ ! -d testrunner ]] ; then git fetch ssh://review.couchbase.org:29418/testrunner $GERRIT_REFSPEC && git checkout FETCH_HEAD ; fi

echo ============================================ make simple-test
cd testrunner
Line1="clitest.healthcheckertest.HealthcheckerTests:"
Line2="     healthchecker_test,sasl_buckets=1,doc_ops=update,GROUP=P0"
Line3="     healthchecker_test,standard_buckets=1,doc_ops=delete,GROUP=P0"

cat > ./cbhealthchecker.conf << EOL
${Line1}
${Line2}
${Line3}
EOL

python ./testrunner -i ini_file.ini -c cbhealthchecker.conf -p get_collectinfo=true

sudo killall -9 beam.smp epmd memcached python  2>&1 > /dev/null || true

echo ============================================ `date`

