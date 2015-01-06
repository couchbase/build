#!/bin/bash -ex
# Launched by the job "repo-sherlock" when a change to the sherlock.xml
# manifest is detected.

# Checkout out the build-team-manifests project to save the build manifest
# for downstream builds.
git config --global user.name "Couchbase Build Team"
git config --global user.email "build-team@couchbase.com"
git config --global color.ui false
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
git commit --allow-empty -m "$msg"
git push origin HEAD:master

# If this script is executing, a change was detected. Time to update the mirror!
cd /home/buildbot/reporef
if [ ! -d .repo ]
then
  repo init -u git://github.com/couchbase/manifest -g all -m sherlock.xml --mirror
fi
repo sync --jobs=6
