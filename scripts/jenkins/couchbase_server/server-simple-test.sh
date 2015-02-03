#!/bin/bash -ex

# This job assumes that it is run in the same Workspace as a successful
# Sherlock build.
#
# Required job parameters (expected to be in environment):
#
# WORKSPACE - from Jenkins
# PLATFORM - from upstream job (to name archived logs)

echo
echo =============== Run simple-test
echo
cd ${WORKSPACE}/testrunner
export COUCHBASE_REPL_TYPE=upr
failed=0
make simple-test || failed=1
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
if [ $failed = 1 ]
then
    echo Tests failed - aborting run
    exit 3
fi
zip cluster_run_log_${PLATFORM} cluster_run.log
