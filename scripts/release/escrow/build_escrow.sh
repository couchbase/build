#!/bin/bash -e

# QQQ keep this list somewhere canonical per build
IMAGES="ceejatec/debian-8-couchbase-build:20171106
ceejatec/debian-9-couchbase-build:20170911
ceejatec/ubuntu-1404-couchbase-build:20170522
ceejatec/centos-70-couchbase-build:20170522
ceejatec/ubuntu-1604-couchbase-cv:20170522
ceejatec/suse-11-couchbase-build:20170522
ceejatec/centos-65-couchbase-build:20170522"

# QQQ possibly keep this list somewhere canonical per build also
GOVERS="1.7.3 1.8.1 1.8.3 1.8.5"

# QQQ parameterize?
RELEASE=5.1.0
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
rm -f ${ESCROW}/deps/dep_list.txt

download_cbdep() {
  dep=$1
  ver=$2
  branch=$3
  cbver=$4

  # Save dep name for the build
  [[ "${dep}" =~ ^boost_ ]] || echo ${dep} >> ${ESCROW}/deps/dep_list.txt

  if [ "${dep}" = "boost" ]
  then
    # Boost is stored in separate repos for 5.0.x; this means copying some logic
    # from tlm/deps/packages/boost, namely the set of repos and the git tag
    for repo in intrusive assert config core detail functional math move mpl \
      optional preprocessor static_assert throw_exception type_index \
      type_traits utility variant
    do
      download_cbdep boost_${repo} $ver boost-1.62.0 $cbver
    done
    return
  fi

  heading "Downloading cbdep ${dep} ${ver}-cb$4 from branch ${branch}..."

  cd ${ESCROW}/deps
  if [ ! -d ${dep} ]
  then
    git clone git://github.com/couchbasedeps/${dep}
    cd ${dep}
    git checkout ${branch}
  fi
}

# QQQ This algorithm assumes that deps/packages/CMakeLists.txt
# describes the versions which were actually used in the build (and this
# is in fact wrong for several deps already - jemalloc and v8).
# Should verify against deps/manifest.cmake, or better, save this
# information canonically per build.
# QQQ Have to manually filter out deps that are not for Server 5.0.0
# below, and also duplicate in templates/in-container-build.sh. These are:
#   libsqlite - for earlier Server versions
#   openssl - only for Windows/Mac
#   libcxx, libcouchbase - for Mobile Lite Core
add_packs=$( \
   grep '_ADD_DEP_PACKAGE(' ${ESCROW}/src/tlm/deps/packages/CMakeLists.txt \
   | sed 's/ *_ADD_DEP_PACKAGE(//' \
   | sed 's/)//' \
   | grep -v libsqlite \
   | grep -v libcxx \
   | grep -v libcouchbase \
   | grep -v openssl \
   | sed 's/\s/:/g' )

for add_pack in ${add_packs}
do
  download_cbdep $(echo ${add_pack} | sed 's/:/ /g')
done

# One unfortunate patch required for flatbuffers to be built with GCC 7
# This should be uncommented when we go to escrow 5.5.0
#cd ${ESCROW}/deps/flatbuffers
#git cherry-pick bbb72f0b
#git tag -f v1.4.0

# One unfortunate tweak required to ensure jemalloc can check out the
# correct branch (the branch is tweaked in in-container-build.sh)
cd ${ESCROW}/deps/jemalloc
git checkout stable-4

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
