#!/bin/bash

LATESTBUILDS=${1-/home/couchbase/latestbuilds}

remove_glob() {
  glob=$1
  days=$2
  echo Removing ${glob} older than ${days} days...
  find . -name ${glob} -atime +${days} -exec sh -c 'echo > "{}"; rm "{}"' \;
}

# @@@@@@@@@
# Clean up Couchbase Server
# @@@@@@@@@
cd ${LATESTBUILDS}/couchbase-server

# All Windows ".bits" files older than 1 day (only needed for intra-build
# communication)
remove_glob "*windows_amd64-bits.tar" 1

# All MacOS .orig files from codesigning
remove_glob "*macos*.orig" 20

# All debug packages older than 30 days
remove_glob "*debug*" 30
remove_glob "*dbg*" 30
remove_glob "*-PDB.zip" 30

# All Ubuntu 14, Debian 8, Centos 7, Suse, Mac, "oel6" builds older than 30 days
remove_glob "*macos*.zip" 30
remove_glob "*ubuntu14.04*.deb" 30
remove_glob "*debian8*.deb" 30
remove_glob "*centos7*.rpm" 30
remove_glob "*suse11*.rpm" 30
remove_glob "*oel6*.rpm" 30


