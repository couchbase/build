#!/bin/bash -e

# Expects ~/.ssh/coverity-token.txt to contain the Coverity Scan token
# for the couchbase-build project.

TOKEN=`cat ~/.ssh/coverity-token.txt`

download_tool() {
  echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  echo Downloading coverity_tool...
  echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  echo
  wget --no-check-certificate https://scan.coverity.com/download/linux-64 --post-data "token=${TOKEN}&project=couchbase%2Fbuild" -O coverity_tool.tgz
  rm -rf cov-analysis-linux64-* cov-analysis
  echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  echo Expanding coverity_tool archive...
  echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  echo
  tar xzf coverity_tool.tgz
  ln -s cov-analysis-linux64-* cov-analysis
}


mkdir -p cov-build
cd cov-build

# Check MD5 to see if we need to re-download
if [ -e coverity_tool.tgz ]
then
  echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  echo Checking validity of coverity_tool.tgz...
  echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  echo
  wget --no-check-certificate https://scan.coverity.com/download/linux-64 --post-data "token=${TOKEN}&project=couchbase%2Fbuild&md5=1" -O coverity_tool.md5
  echo "`cat coverity_tool.md5`  coverity_tool.tgz" | md5sum -c || {
    echo "MD5 checksum has changed! Re-downloading coverity_tool..."
    download_tool
  }
else
  download_tool
fi

export PATH=${PATH}:`pwd`/cov-analysis/bin
cd ..

mkdir -p repo
cd repo
echo
echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo Downloading couchbase source code...
echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo

# Delete everything but the .repo directory, if it happens to exist
rm -rf *
git config --global user.name "Couchbase Build Team"
git config --global user.email "build-team@couchbase.com"
git config --global color.ui false
repo init -u git://github.com/couchbase/build-team-manifests -g all -m watson.xml
repo sync --jobs=6
BLD_NUM=`repo forall build -c 'echo $REPO__BLD_NUM'`

echo
echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo Building 4.5.0-${BLD_NUM}...
echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo
export CCACHE_DISABLE=true
time cov-build --dir cov-int make -j8

echo
echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo Compressing Coverity scan results...
echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
tar czf ../couchbase-build.tgz cov-int

echo
echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo Upload scan to Coverity...
echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
curl --insecure \
  --form token="${TOKEN}" \
  --form email="ceej+github@lambda.nu" \
  --form file="@../couchbase-build.tgz" \
  --form version="4.5.0-${BLD_NUM}" \
  --form description="Couchbase Server Watson 4.5.0-${BLD_NUM}" \
  https://scan.coverity.com/builds?project=couchbase%2Fbuild

