#!/bin/bash -ex
# Launched by the job "repo-sherlock" when a change to the sherlock.xml
# manifest is detected.

# Checkout out the build-team-manifests project to save the build manifest
# for downstream builds.
if [ ! -d build-team-manifests ]
then
    git clone ssh://git@github.com/couchbase/build-team-manifests
else
    (cd build-team-manifests; git pull)
fi

# Save the build manifest.
repo manifest -r > build-team-manifests/sherlock.xml
cd build-team-manifests
git add sherlock.xml
msg="Sherlock build ${BUILD_NUMBER} at "`date`
git commit -m "$msg"
git push origin HEAD:master

# If this script is executing, a change was detected. Time to update the mirror!
cd /home/buildbot/reporef
repo sync --jobs=6
