#!/bin/bash -ex
# This script is used by couchbase-edge-server-linux on Mobile Jenkins
# PRODUCT, VERSION, and BLD_NUM are set by the job.

# Prepare staging area for packaging
if [[ -d ${PRODUCT} ]]; then
    rm -rf ${PRODUCT}
fi
cp -rp ${WORKSPACE}/edge-server/install ${PRODUCT}

# Get build agent's docker id
# sidecar needs to know where to mount the volume.
NODE_NAME=$(uname -n)

# build rpm and deb
ruby package-rpm.rb couchbase-edge-server ${PRODUCT} ${VERSION}-${BLD_NUM} x86_64
docker run --rm --pull=always --volumes-from ${NODE_NAME} --workdir `pwd` --user 1000:1000 \
    couchbasebuild/server-deb-sidecar:latest ruby package-deb.rb ${PRODUCT} \
    ${PRODUCT} ${VERSION}-${BLD_NUM} amd64

# copy deb and rpm to make it easier for Jenkins to publish
cp build/deb/*.deb ${WORKSPACE}
cp build/rpm/${PRODUCT}_${VERSION}-${BLD_NUM}/rpmbuild/RPMS/*/*.rpm ${WORKSPACE}
