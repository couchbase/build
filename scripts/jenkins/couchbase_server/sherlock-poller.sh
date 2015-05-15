#!/bin/bash -ex
# Launched by "repo-sherlock" to see if a new build needs to be triggered.
#
# Expects "PRODUCT_BRANCH" to be specified in the environment.

# Clean previous artifacts.
rm -f current.xml trigger.properties

# Check out the build-team-manifests project to compare with the previous build.
git config --global user.name "Couchbase Build Team"
git config --global user.email "build-team@couchbase.com"
git config --global color.ui false
if [ ! -d build-team-manifests ]
then
    git clone ssh://git@github.com/couchbase/build-team-manifests
else
    (cd build-team-manifests; git pull)
fi
(cd build-team-manifests; git checkout ${PRODUCT_BRANCH})

# Write out the current build manifest.
repo manifest -r > current.xml

# See if it is different than the tip of build-team-manifests.
diffchars=`repo diffmanifests ${WORKSPACE}/current.xml ${WORKSPACE}/build-team-manifests/sherlock.xml --raw | wc -c`
if [ "${diffchars}" = "0" ]
then
    echo "No differences since last build - not triggering downstream build"
else
    # Create trigger.properties with dummy content, to make Jenkins trigger
    # the downstream build
    echo "BUILD=yes" > trigger.properties
    echo "Manifest differences found - triggering downstream build!"
fi
