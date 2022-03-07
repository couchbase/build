#!/bin/bash -ex
# Launched by the job "watson-build" to start a new build.
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
cp build-team-manifests/watson.xml .repo/manifests/last-build.xml

# Write out the new build manifest.
repo manifest -r > build-team-manifests/watson.xml

# get changelog - last build to current build
rm -f CHANGELOG
repo diffmanifests last-build.xml `pwd`/build-team-manifests/watson.xml > CHANGELOG

# Play fun repo games to figure out the last build's build number, and add 1.
repo init -m last-build.xml -g all
bldnum=$(( `repo forall build -c 'echo $REPO__BLD_NUM'` + 1))

# Ensure input manifest has a @BLD_NUM@ token.
cd build-team-manifests
if ! grep -q @BLD_NUM@ watson.xml
then
    echo "Input manifest missing @BLD_NUM@!!"
    exit 5
fi

# Update and commit the new build manifest
sed -i "s/@BLD_NUM@/${bldnum}/g" watson.xml
git add watson.xml
msg="Watson '${PRODUCT_BRANCH}' build ${VERSION}-${bldnum} at "`date`
git commit --allow-empty -m "$msg"
git push origin HEAD:${PRODUCT_BRANCH}

# Also save it with the right name for uploading to latestbuilds.
rm -f ${WORKSPACE}/*.xml
cp watson.xml ${WORKSPACE}/couchbase-server-${VERSION}-${bldnum}-manifest.xml

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
  repo init -u https://github.com/couchbase/manifest -g all -m watson.xml --mirror
fi
repo sync --jobs=6

#run unit test and simple-test at midnight by default
#it can also be run other times by manually setting the parameter in jenkins job

hour=`date +"%H"`
run_unit=${UNIT_TEST:-false}
# shouldn't happen if the var is jenkins bool param,
# but checking for any spurious values anyway...
if [[ "${run_unit}" != "true" ]]; then
    run_unit=false
fi
if [[ "${run_unit}" = "false" ]]; then
    if [[ "$hour" = "00" ]]; then
        run_unit=true
    fi
fi
echo "UNIT_TEST=${run_unit}" >> ${WORKSPACE}/trigger.properties

run_simple=${SIMPLE_TEST:-false}
if [[ "${run_simple}" != "true" ]]; then
    run_simple=false
fi
if [[ "${run_simple}" = "false" ]]; then
    if [[ "$hour" = "00" ]]; then
        run_simple=true
    fi
fi
echo "SIMPLE_TEST=${run_simple}" >> ${WORKSPACE}/trigger.properties
