#!/bin/bash
#  
#  Seed local debian and rpm repos for OpenSSL libraries.  Step 2 of five:
#  
#   1.  prepare local openssl098 repos
#   2.  seed new repos
#   3.  import packages
#   4.  sign RPM packges in local repos
#   5.  upload local repos to shared repository
#  
if [[ ! ${LOCAL_SSL_ROOT} ]] ; then  LOCAL_SSL_ROOT=~/linux_repos/openssl098 ; fi

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi


                                              DEB_REPO=${LOCAL_SSL_ROOT}/deb
echo ""
echo "creating new DEB openssl098 repo at:  ${DEB_REPO}"
rm    -rf                                   ${DEB_REPO}
mkdir  -p                                   ${DEB_REPO}
echo ""
echo "DEB openssl098 repo ready for import: ${DEB_REPO}"
echo ""


                                              RPM_REPO=${LOCAL_SSL_ROOT}/rpm
echo ""
echo "creating new RPM openssl098 repo at:  ${RPM_REPO}"
echo ""
rm   -rf ${RPM_REPO}
mkdir -p ${RPM_REPO}
mkdir -p ${RPM_REPO}/5/x86_64
mkdir -p ${RPM_REPO}/5/i386
mkdir -p ${RPM_REPO}/6/x86_64
mkdir -p ${RPM_REPO}/6/i386

createrepo --verbose  ${RPM_REPO}/5/x86_64
createrepo --verbose  ${RPM_REPO}/6/x86_64

createrepo --verbose  ${RPM_REPO}/5/i386
createrepo --verbose  ${RPM_REPO}/6/i386
echo ""
echo "RPM openssl098 repo ready for import: ${RPM_REPO}"
echo ""
