#!/bin/bash -e

# QQQ keep this list somewhere canonical per build
IMAGES="couchbasebuild/server-centos6-build:20180713
couchbasebuild/server-centos7-build:20180829
couchbasebuild/server-debian8-build:20181017
couchbasebuild/server-debian9-build:20181017
couchbasebuild/server-suse11-build:20180713
couchbasebuild/server-ubuntu14-build:20180829
couchbasebuild/server-ubuntu16-build:20181017"

# QQQ possibly keep this list somewhere canonical per build also
GOVERS="1.7.6 1.8.3 1.8.5 1.9.6 1.10.3"

# QQQ parameterize?
VERSION=6.0.0
PRODUCT=couchbase-server

# QQQ extract from tlm/deps/packages/boost/CMakeLists.txt
BOOST_MODULES="intrusive assert config core detail functional math move mpl
optional preprocessor static_assert throw_exception type_index
type_traits utility variant"

# QQQ extract from asterix-opt/cmake/Modules/FindCouchbaseJava.cmake
JDKVER=8u181

# END normal per-version configuration variables

# Compute list of platforms from Docker image names
# (will need to change this algorithm if we change the
# Docker image naming convention)
PLATFORMS=$(
  perl -e 'print join(" ", map { m@couchbasebuild/server-(.*)-build@ && $1} @ARGV)' $IMAGES
)

heading() {
  echo
  echo ::::::::::::::::::::::::::::::::::::::::::::::::::::
  echo $*
  echo ::::::::::::::::::::::::::::::::::::::::::::::::::::
  echo
}

# Top-level directory; everything to escrow goes in here.
ROOT=`pwd`
ESCROW=${ROOT}/${PRODUCT}-${VERSION}
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
heading "Downloading released source code for ${PRODUCT} ${VERSION}..."
mkdir -p ${ESCROW}/src
cd ${ESCROW}/src
git config --global user.name "Couchbase Build Team"
git config --global user.email "build-team@couchbase.com"
git config --global color.ui false
repo init -u git://github.com/couchbase/manifest -g all -m released/${VERSION}.xml
repo sync --jobs=6

# Ensure we have git history for 'master' branch of tlm, so we can
# switch to the right cbdeps build steps
( cd tlm && git fetch couchbase refs/heads/master )

# Download all cbdeps source code
mkdir -p ${ESCROW}/deps

get_cbdep_git() {
  local dep=$1

  cd ${ESCROW}/deps
  if [ ! -d ${dep} ]
  then
    heading "Downloading cbdep ${dep} ..."
    # This special approach ensures all remote branches are brought
    # down as well, which ensures in-container-build.sh can also check
    # them out. See https://stackoverflow.com/a/37346281/1425601 .
    mkdir ${dep}
    cd ${dep}
    git clone --bare git://github.com/couchbasedeps/${dep} .git
    git config core.bare false
    git checkout
  fi
}

download_cbdep() {
  local dep=$1
  local ver=$2
  local dep_manifest=$3

  if [ "${dep}" = "boost" ]
  then
    # Boost is stored in separate repos; this means copying some logic
    # from tlm/deps/packages/boost, namely the set of repos
    for repo in ${BOOST_MODULES}
    do
      get_cbdep_git boost_${repo}
    done
  # skip openjdk-rt cbdeps build
  elif [[ ${dep} == 'openjdk-rt' ]]; then
    :
  else
    get_cbdep_git ${dep}
  fi

  # Split off the "version" and "build number"
  version=$(echo ${ver} | perl -nle '/^(.*?)(-cb.*)?$/ && print $1')
  cbnum=$(echo ${ver} | perl -nle '/-cb(.*)/ && print $1')

  # Figure out the tlm SHA which builds this dep
  tlmsha=$(
    cd ${ESCROW}/src/tlm &&
    git grep -c "_ADD_DEP_PACKAGE(${dep} ${version} .* ${cbnum})" \
      $(git rev-list --all -- deps/packages/CMakeLists.txt) \
      -- deps/packages/CMakeLists.txt \
    | awk -F: '{ print $1 }' | head -1
  )

  if [ -z "${tlmsha}" ]; then
    echo "ERROR: couldn't find tlm SHA for ${dep} ${version} @${cbnum}@"
    exit 1
  fi

  echo "${dep}:${tlmsha}" >> ${dep_manifest}
}

# Determine set of cbdeps used by this build, per platform.
for platform in ${PLATFORMS}
do

  add_packs=$(
    grep ${platform} ${ESCROW}/src/tlm/deps/manifest.cmake \
    | awk '{sub(/\(/, "", $2); print $2 ":" $4}'
  )

  # Download and keep a record of all third-party deps
  dep_manifest=${ESCROW}/deps/dep_manifest_${platform}.txt
  rm -f ${dep_manifest}
  for add_pack in ${add_packs}
  do
    download_cbdep $(echo ${add_pack} | sed 's/:/ /g') ${dep_manifest}
  done

  # Ensure that snappy is built first (before python-snappy)
  grep '^snappy' ${dep_manifest} > ${ESCROW}/deps/dep2.txt
  grep -v '^snappy' ${dep_manifest} >> ${ESCROW}/deps/dep2.txt
  mv ${ESCROW}/deps/dep2.txt ${dep_manifest}

done

# Need this tool for v8 build
get_cbdep_git depot_tools

# Copy in pre-packaged JDK
jdkfile=jdk-${JDKVER}-linux-x64.tar.gz
curl -o ${ESCROW}/deps/${jdkfile} http://nas-n.mgt.couchbase.com/builds/downloads/jdk/${jdkfile}

# One unfortunate patch required for flatbuffers to be built with GCC 7
heading "Patching flatbuffers for GCC 7"
cd ${ESCROW}/deps/flatbuffers
git checkout v1.4.0 > /dev/null
if [ $(git rev-parse HEAD) = "eba6b6f7c93cab4b945f1e39d9ef413d51d3711d" ]
then
  git cherry-pick bbb72f0b
  git tag -f v1.4.0
fi

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
perl -pi -e "s/\@\@VERSION\@\@/${VERSION}/g; s/\@\@PLATFORMS\@\@/${PLATFORMS}/g" \
  ${ESCROW}/README.md ${ESCROW}/build-couchbase-server-from-escrow.sh

heading "Creating escrow tarball (will take some time)..."
cd ${ROOT}
tar czf ${PRODUCT}-${VERSION}.tar.gz ${PRODUCT}-${VERSION}

heading "Done!"
