#!/bin/bash -e

# These platforms correspond to the available Docker buildslave images.
PLATFORMS="@@PLATFORMS@@"

usage() {
  echo "Usage: $0 <platform>"
  echo "  where <platform> is one of: ${PLATFORMS}"
  exit 1
}

# Check input argument
if [ $# -eq 0 ]
then
  usage
fi
PLATFORM=$1

sup=$(echo ${PLATFORMS} | egrep "\b${PLATFORM}\b" || true)
if [ -z "${sup}" ]
then
  echo "Unknown platform $1"
  usage
fi

# Ensure docker
docker version > /dev/null 2>&1
if [ $? -ne 0 ]
then
  echo "Docker is required to be installed!"
  exit 5
fi

heading() {
  echo
  echo ::::::::::::::::::::::::::::::::::::::::::::::::::::
  echo $*
  echo ::::::::::::::::::::::::::::::::::::::::::::::::::::
  echo
}

ROOT=`pwd`

# Load Docker buildslave image for desired platform
cd docker_images
IMAGE=couchbasebuild/$( basename -s .tar.gz $( ls server-${PLATFORM}* ) )
if [[ -z "`docker images -q ${IMAGE}`" ]]
then
  heading "Loading Docker image ${IMAGE}..."
  gzip -dc ${PLATFORM}* | docker load
fi

# Run Docker buildslave
SLAVENAME="${PLATFORM}-buildslave"
cd ${ROOT}
set +e
docker inspect ${SLAVENAME} > /dev/null 2>&1
if [ $? -ne 0 ]
then
  heading "Starting Docker buildslave container..."
  # We specify external DNS (Google's) to ensure we don't find
  # things on our LAN. We also point packages.couchbase.com to
  # a bogus IP to ensure we aren't dependent on existing packages.
  docker run -d --name ${SLAVENAME} \
    --add-host packages.couchbase.com:8.8.8.8 \
    --dns 8.8.8.8 \
    -v `pwd`:/escrow \
    ${IMAGE} default
fi
set -e

# Load local copy of escrowed source code into container
heading "Copying escrowed sources and dependencies into container"
docker exec -it ${SLAVENAME} rm -rf /home/couchbase/escrow
docker exec -it ${SLAVENAME} mkdir -p /home/couchbase/escrow
docker exec -it ${SLAVENAME} cp -a /escrow/in-container-build.sh \
  /escrow/deps /escrow/golang /escrow/src /home/couchbase/escrow
docker exec -it ${SLAVENAME} chown -R couchbase:couchbase /home/couchbase

# Launch build process
heading "Running full Couchbase Server build in container..."
docker exec -it -u couchbase ${SLAVENAME} bash \
  /home/couchbase/escrow/in-container-build.sh ${PLATFORM} @@VERSION@@

# And copy the installation packages out of the container.
heading "Copying installer binaries"
for file in `docker exec ${SLAVENAME} bash -c \
  "ls /home/couchbase/escrow/src/*${PLATFORM}*"`
do
  docker cp ${SLAVENAME}:${file} .
  localfile=`basename ${file}`
  mv ${localfile} ${localfile/-9999/}
done

