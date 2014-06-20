#!/bin/bash -h
#              (ignore SIGHUP)
#              
#       Staging (step 1 of 3) 
#              
#       Download and upload to s3
#       along with .staging files
set -e

if [[ ! ${WORKSPACE} ]] ; then WORKSPACE=`pwd` ; fi

TMP_DIR=${WORKSPACE}/release_tmp
PHONE_HOME=${WORKSPACE}/phone_home.txt
if [[ -e ${PHONE_HOME} ]] ; then rm -f ${PHONE_HOME} ; fi


usage()
    {
    echo ""
    echo "usage:  `basename $0`  RELEASE  VERSION  PRODUCT  EDITION  [ -D TMP_DIR ]"
    echo ""
    echo "           RELEASE        release number, like 3.0.0 or 2.5.2          "
    echo "           VERSION        prepared version, like 3.0.0 or 3.0.0-beta   "
    echo "           PRODUCT        android, ios, or sync_gateway (one only)     "
    echo "           EDITION        community or enterprise.                     "
    echo ""
    echo "          [-D TMP_DIR ]   temp dir to use, if not ${TMP_DIR}"
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


####    optional, named arguments

while getopts "D:h" OPTION; do
  case "$OPTION" in
      D)
        TMP_DIR="$OPTARG"
        ;;
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


echo "Create tmp folder to hold all the packages"
rm      -rf ${TMP_DIR}
mkdir   -p  ${TMP_DIR}
chmod   777 ${TMP_DIR}
pushd       ${TMP_DIR}  2>&1 > /dev/null


s3_build_src="s3://packages.couchbase.com/builds/mobile/${product}/${release}/${version}"
GET_CMD="s3cmd get"
PUT_CMD="s3cmd put"

if  [[ ${product} == 'android' ]]
    then
    if [[ ${edition} == 'enterprise' ]]  ; then  pkgs="couchbase-lite-${version}-android.zip"           ; fi
    if [[ ${edition} == 'community'  ]]  ; then  pkgs="couchbase-lite-${version}-android-community.zip" ; fi
    s3_relbucket="s3://packages.couchbase.com/releases/couchbase-lite/${product}/${version}"
fi
 
if  [[ ${product} == 'ios' ]]
    then
    if [[ ${edition} == 'enterprise' ]]  ; then  pkgs="couchbase-lite-ios-enterprise_${version}.zip couchbase-lite-ios-enterprise_${version}_Documentation.zip" ; fi
    if [[ ${edition} == 'community'  ]]  ; then  pkgs="couchbase-lite-ios-community_${version}.zip  couchbase-lite-ios-community_${version}_Documentation.zip"  ; fi
    s3_relbucket="s3://packages.couchbase.com/releases/couchbase-lite/${product}/${version}"
fi
 
if  [[ ${product} == 'sync_gateway' ]]
    then
    pkgs=""
    PREFIX="couchbase-sync-gateway"
    EE_pkgs="x86_64.rpm            i386.rpm             macosx-x86_64.tar.gz            amd64.deb            i386.deb"
    CE_pkgs="x86_64-community.rpm  i386-community.rpm   macosx-x86_64-community.tar.gz  amd64-community.deb  i386-community.deb"
    
    if [[ ${edition} == 'enterprise' ]] ; then  pkg_ends=$EE_pkgs ; fi
    if [[ ${edition} == 'community' ]]  ; then  pkg_ends=$CE_pkgs ; fi
    
    for src in ${pkg_ends[@]} ; do pkgs="$pkgs ${PREFIX}_${version}_${src}" ; done
    
    PREFIX="setup_couchbase-sync-gateway"
    EE_pkgs="amd64.exe           x86.exe"
    CE_pkgs="amd64-community.exe x86-community.exe"
    
    if [[ ${edition} == 'enterprise' ]] ; then  pkg_ends=$EE_pkgs ; fi
    if [[ ${edition} == 'community' ]]  ; then  pkg_ends=$CE_pkgs ; fi
    
    for src in ${pkg_ends[@]} ; do pkgs="$pkgs ${PREFIX}_${version}_${src}" ; done
    
    s3_relbucket="s3://packages.couchbase.com/releases/couchbase-sync-gateway/${release}/${version}"
fi

####################   S T A R T  H E R E


for this_pkg in ${pkgs[@]}
  do
    echo "Staging:  ${s3_relbucket}/${this_pkg}"
    echo "download  ${s3_build_src}/${this_pkg}"
    ${GET_CMD}      ${s3_build_src}/${this_pkg}
    
    if [[ ! -e ${this_pkg} ]] ; then echo "FAILED to download ${s3_build_src}/${this_pkg}" ; exit 404 ; fi
    
    echo "create staging file for ${this_pkg}"
    touch "${this_pkg}.staging"
    
    echo "calculate md5sum for   ${this_pkg}"
    md5sum ${this_pkg} > ${this_pkg}.md5
    
    echo --------- ${PUT_CMD}  ${s3_relbucket}/${this_pkg}.staging
    echo --------- ${PUT_CMD}  ${s3_relbucket}/${this_pkg}.md5
    echo --------- ${PUT_CMD}  ${s3_relbucket}/${this_pkg}
    echo $package >> ${PHONE_HOME}
    echo --------- rm ${this_pkg}
done
 
echo "Granting anonymous read access..."
s3cmd setacl --acl-public --recursive "${s3_relbucket}/"

s3cmd ls "${s3_relbucket}/"
popd                    2>&1 > /dev/null
