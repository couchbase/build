#!/bin/bash -h
#              (ignore SIGHUP)
#              
#       Release (step 2 of 3) 
#              
#       Remove the .staging files
#       packages become available
set -e

if [[ ! ${WORKSPACE} ]] ; then WORKSPACE=`pwd` ; fi


usage()
    {
    echo ""
    echo "usage:  `basename $0`   RELEASE   VERSION   PRODUCT   EDITION          "
    echo ""
    echo "           RELEASE        release number, like 3.0.0 or 2.5.2          "
    echo "           VERSION        prepared version, like 3.0.0 or 3.0.0-beta   "
    echo "           PRODUCT        android, ios, or sync_gateway (one only)     "
    echo "           EDITION        community or enterprise.                     "
    echo ""
    echo "           -h             print this help message"
    echo ""
    exit 4
    }
if [[ $1 == "--help" ]] ; then usage ; fi


####    required, positional arguments

if [[ ! ${1} ]] ; then echo ; echo "RELEASE required (1.0.1, 1.0.0, ...)"          ; usage ; exit ; fi
release=${1}

if [[ ! ${2} ]] ; then echo ; echo "VERSION required (from prepare_release step)"  ; usage ; exit ; fi
version=${2}

if [[ ! ${3} ]] ; then echo ; echo "PRODUCT required (android, ios, sync_gateway)" ; usage ; exit ; fi
product=${3}

if [[ ! ${4} ]] ; then echo ; echo "EDITION required (enterprise, community)"      ; usage ; exit ; fi
edition=${4}

rel_dir=${release}/${version}
if [[ ${release} == ${version} ]] ; then rel_dir=${release} ; fi


####    optional, named arguments

while getopts "D:h" OPTION; do
  case "$OPTION" in
      h)
        usage
        exit 0
        ;;
      *)
        usage
        exit 9
        ;;
  esac
done


DEL_CMD="s3cmd del"

if  [[ ${product} == 'android' ]]
  then
    pkgs="couchbase-lite-android-${edition}_${version}.zip"
    s3_relbucket="s3://packages.couchbase.com/releases/couchbase-lite/${product}/${rel_dir}"
fi
 
if  [[ ${product} == 'ios' ]]
  then
    pkgs="couchbase-lite-ios-${edition}_${version}.zip couchbase-lite-ios-${edition}_${version}_Documentation.zip"
    s3_relbucket="s3://packages.couchbase.com/releases/couchbase-lite/${product}/${rel_dir}"
fi
 
if  [[ ${product} == 'sync_gateway' ]]
  then
    pkgs=""
    PREFIX="couchbase-sync-gateway"
    pkg_ends="x86_64.rpm  x86.rpm  x86_64.tar.gz  x86_64.deb  x86.deb  x86_64.exe  x86.exe"
    
    for end in ${pkg_ends[@]} ; do pkgs="$pkgs ${PREFIX}_${version}_${end}" ; done
    
    s3_relbucket="s3://packages.couchbase.com/releases/couchbase-sync-gateway/${rel_dir}"
fi

####################   S T A R T  H E R E


for this_pkg in ${pkgs[@]}
  do
    echo "Undo Release and Staging:  ${s3_relbucket}/${this_pkg}"

    ${DEL_CMD}  ${s3_relbucket}/${this_pkg}.staging
    ${DEL_CMD}  ${s3_relbucket}/${this_pkg}.md5
    ${DEL_CMD}  ${s3_relbucket}/${this_pkg}
done
 
s3cmd ls "${s3_relbucket}/ --recursive"
