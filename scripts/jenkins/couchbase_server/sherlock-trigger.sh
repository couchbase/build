#!/bin/bash -ex
# Launched by the job "sherlock-build" to start a new build.
#
# Expects "PRODUCT_BRANCH" and "VERSION" to be specified in the environment,
# in addition to "WORKSPACE".

# Checkout out the build-team-manifests project to save the build manifest
# for downstream builds.
git config --global user.name "Couchbase Build Team"
git config --global user.email "build-team@couchbase.com"
git config --global color.ui false
if [ ! -d build-team-manifests ]
then
    git clone ssh://git@github.com/couchbase/build-team-manifests
fi
(cd build-team-manifests && git checkout ${PRODUCT_BRANCH} && git pull)

# Save a copy of the previous build manifest before overwriting it.
cp build-team-manifests/sherlock.xml .repo/manifests/last-build.xml

# Write out the new build manifest.
repo manifest -r > build-team-manifests/sherlock.xml

# Play fun repo games to figure out the last build's build number, and add 1.
repo init -m last-build.xml -g all
bldnum=$(( `repo forall build -c 'echo $REPO__BLD_NUM'` + 1))

# Update and commit the new build manifest
cd build-team-manifests
sed -i "s/@BLD_NUM@/${bldnum}/g" sherlock.xml
git add sherlock.xml
msg="${PRODUCT_BRANCH} build ${bldnum} at "`date`
git commit --allow-empty -m "$msg"
git push origin HEAD:${PRODUCT_BRANCH}

# Also save it with the right name for uploading to latestbuilds.
rm -f ${WORKSPACE}/*.xml
cp sherlock.xml ${WORKSPACE}/couchbase-server-${VERSION}-${bldnum}-manifest.xml

# Save the new commit SHA and the build number for downstream jobs in
# "trigger.properties".
echo -n "MANIFEST_SHA=" > ${WORKSPACE}/trigger.properties
git rev-parse HEAD >> ${WORKSPACE}/trigger.properties
echo "BLD_NUM=${bldnum}" >> ${WORKSPACE}/trigger.properties

# Update the reporef mirror for downstream jobs that can share it.
mkdir -p ~/reporef
cd ~/reporef
if [ ! -d .repo ]
then
  repo init -u git://github.com/couchbase/manifest -g all -m sherlock.xml --mirror
fi
repo sync --jobs=6
