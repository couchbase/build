#!/bin/bash
#
#          run by jenkins job 'make-simple-github' and 'make-simple-github-upr'
#
#          with parameter either 'upr' or 'tap' (default will be 'tap')
#
#          triggered every three hours
#

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
rm -rf testrunner/cluster_run.log
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard
repo forall -c "git clean -xfd"

echo ============================================ make
make all install
echo ============================================ make simple-test
cd testrunner
export COUCHBASE_REPL_TYPE=${1-tap}
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
zip cluster_run_log cluster_run.log
echo ============================================ `date`
