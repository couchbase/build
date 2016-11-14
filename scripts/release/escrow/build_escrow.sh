#!/bin/bash -e

# QQQ keep this list somewhere canonical per build
IMAGES="ceejatec/debian-7-couchbase-build:20160229 
ceejatec/debian-8-couchbase-build:20160112 
ceejatec/ubuntu-1404-couchbase-build:20151223 
ceejatec/centos-70-couchbase-build:20151223 
ceejatec/ubuntu-1204-couchbase-build:20151223 
ceejatec/suse-11-couchbase-build:20151223 
ceejatec/centos-65-couchbase-build:20151223"

# QQQ possibly keep this list somewhere canonical per build also
GOVERS="1.4.2 1.5.2 1.6"

# QQQ parameterize?
RELEASE=4.5.0
PRODUCT=couchbase-server

heading() {
  echo
  echo ::::::::::::::::::::::::::::::::::::::::::::::::::::
  echo $*
  echo ::::::::::::::::::::::::::::::::::::::::::::::::::::
  echo
}

# Top-level directory; everything to escrow goes in here.
ROOT=`pwd`
ESCROW=${ROOT}/${PRODUCT}-${RELEASE}
mkdir -p ${ESCROW}

# Save copies of all Docker build images
echo "Saving Docker images..."
mkdir -p ${ESCROW}/docker_images
cd ${ESCROW}/docker_images
for img in ${IMAGES}
do
  heading "Saving Docker image ${img}"  
  echo "... Pulling ${img}..."
  docker pull ${img}
  echo "... Saving local copy of ${img}..."
  output=`basename ${img}`.tar.gz
  if [ ! -s "${output}" ]
  then
    docker save ${img} | gzip > ${output}
  fi
done

# Get the source code
heading "Downloading released source code for ${PRODUCT} ${RELEASE}..."
mkdir -p ${ESCROW}/src
cd ${ESCROW}/src
git config --global user.name "Couchbase Build Team"
git config --global user.email "build-team@couchbase.com"
git config --global color.ui false
# QQQ Path to manifest is Couchbase Server-specific
repo init -u git://github.com/couchbase/manifest -g all -m released/${RELEASE}.xml
repo sync --jobs=6

mkdir -p ${ESCROW}/deps
download_cbdep() {
  dep=$1
  ver=$2-cb$4
  branch=$3
  heading "Downloading cbdep ${dep} ${ver} from branch ${branch}..."
  cd ${ESCROW}/deps
  if [ ! -d ${dep} ]
  then
    git clone git://github.com/couchbasedeps/${dep}
    cd ${dep}
    git checkout ${branch}
  fi
}

# QQQ This algorithm assumes that deps/packages/CMakeLists.txt 
# describes the versions which were actually used in the build.
# Should verify against deps/manifest.cmake, or better, save this
# information canonically per build.
add_packs=$( \
   grep '_ADD_DEP_PACKAGE(' ${ESCROW}/src/tlm/deps/packages/CMakeLists.txt \
   | sed 's/ *_ADD_DEP_PACKAGE(//' \
   | grep -v gperftools \
   | sed 's/)//' \
   | sed 's/\s/:/g' )

for add_pack in ${add_packs}
do
  download_cbdep $(echo ${add_pack} | sed 's/:/ /g')
done

heading "Downloading Go installers..."
mkdir -p ${ESCROW}/golang
cd ${ESCROW}/golang
for gover in ${GOVERS}
do
  echo "... Go ${gover}..."
  gofile="go${gover}.linux-amd64.tar.gz"
  if [ ! -e ${gofile} ]
  then
    curl -o ${gofile} http://storage.googleapis.com/golang/${gofile}
  fi
done

heading "Copying build scripts into escrow..."
cd ${ROOT}
cp -a templates/* ${ESCROW}

heading "Done!"

