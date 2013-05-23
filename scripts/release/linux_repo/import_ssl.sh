#!/bin/bash
#  
#  Import OpenSSL libraries into local debian and rpm repos.  Step 3 of five:
#  
#   1.  prepare local openssl098 repos
#   2.  seed new repos
#   3.  import packages
#   4.  sign RPM packges in local repos
#   5.  upload local repos to shared repository
#  
if [[ ! ${LOCAL_SSL_ROOT} ]] ; then  LOCAL_SSL_ROOT=~/linux_repos/openssl098 ; fi

function usage
    {
    echo ""
    echo "use:  `basename $0`  [ LOCAL_SSL_SRC ]"
    echo ""
    echo "      Imports openssl098 libraries into local repo,"
    echo "      both debian and rpm packages."
    echo ""
    echo ""
    echo "Note:  These files must be in the local workspace, or be pointed to by"
    echo "       environment variable LOCAL_SSL_SRC:"
    echo ""
    echo "       rpm:"
    echo ""
    echo "         openssl-0.9.8e-22.el5_8.4.i686.rpm"
    echo "         openssl-0.9.8e-22.el5_8.4.x86_64.rpm"
    echo "         openssl-0.9.8e-22.el5_8.4.i386.rpm"
    echo "         openssl-0.9.8e-22.el5_8.4.i686.rpm"
    echo "         openssl098e-0.9.8e-17.el6.centos.2.i686.rpm"
    echo "         openssl098e-0.9.8e-17.el6.centos.2.x86_64.rpm"
    echo "         openssl098e-0.9.8e-17.el6.centos.2.i686.rpm"
    echo ""
    echo "       debian:"
    echo ""
    echo "         libssl0.9.8_0.9.8o-7ubuntu3.1_amd64.deb"
    echo "         libssl0.9.8_0.9.8o-7ubuntu3.1_i386.deb"
    echo "         libssl0.9.8_0.9.8k-7ubuntu8.14_amd64.deb"
    echo "         libssl0.9.8_0.9.8k-7ubuntu8.14_i386.deb "
    echo ""
    echo "       If not defined, current directory is used."
    echo "       Optional argment overrides env.var is defined."
    echo ""
    }
if [[ ! ${LOCAL_SSL_SRC} ]] ; then LOCAL_SSL_SRC=`pwd` ; fi
if [[ ${1} ]]               ; then LOCAL_SSL_SRC=${1}  ; fi

DEB_REPO=${LOCAL_SSL_ROOT}/deb
RPM_REPO=${LOCAL_SSL_ROOT}/rpm


function import_package
    {
    local FILE=$1
    local DEST=$2
    
    if [[ ! -f ${LOCAL_SSL_SRC}/${FILE} ]] ; then echo -e "\nFile not found: ${LOCAL_SSL_SRC}/${FILE}\n" ; usage ; exit 99 ; fi
    
    if [[ ! -z ${DEST} ]] 
        then
        if [[ -d ${DEST} ]] 
          then
            cp         ${LOCAL_SSL_SRC}/${FILE}  ${DEST}
            echo      "${LOCAL_SSL_SRC}/${FILE}  imported into ${DEST}"
          else
            echo -e "\nNo such directory:  ${DEST}\n" ; usage ; exit 88
        fi
    fi
    }

echo ""
echo "RPM:  Importing into local openssl098 repo at ${RPM_REPO}"
echo ""

import_package  openssl-0.9.8e-22.el5_8.4.i686.rpm              ${RPM_REPO}/5/x86_64
import_package  openssl-0.9.8e-22.el5_8.4.x86_64.rpm            ${RPM_REPO}/5/x86_64
import_package  openssl-0.9.8e-22.el5_8.4.i386.rpm              ${RPM_REPO}/5/i386
import_package  openssl-0.9.8e-22.el5_8.4.i686.rpm              ${RPM_REPO}/5/i386

import_package  openssl098e-0.9.8e-17.el6.centos.2.i686.rpm     ${RPM_REPO}/6/x86_64
import_package  openssl098e-0.9.8e-17.el6.centos.2.x86_64.rpm   ${RPM_REPO}/6/x86_64
import_package  openssl098e-0.9.8e-17.el6.centos.2.i686.rpm     ${RPM_REPO}/6/i386

echo ""
echo "updating ${RPM_REPO}"
echo ""

createrepo --update  ${RPM_REPO}/5/x86_64
createrepo --update  ${RPM_REPO}/6/x86_64

createrepo --update  ${RPM_REPO}/5/i386
createrepo --update  ${RPM_REPO}/6/i386

echo ""
echo "repo ready for signing: ${RPM_REPO}"
echo ""


echo ""
echo "DEB:  Importing into local openssl098 repo at ${DEB_REPO}"
echo ""

import_package                                                                                            libssl0.9.8_0.9.8o-7ubuntu3.1_amd64.deb
reprepro -T deb -V --ignore=wrongdistribution --basedir ${DEB_REPO}  includedeb  precise ${LOCAL_SSL_SRC}/libssl0.9.8_0.9.8o-7ubuntu3.1_amd64.deb
import_package                                                                                            libssl0.9.8_0.9.8o-7ubuntu3.1_i386.deb
reprepro -T deb -V --ignore=wrongdistribution --basedir ${DEB_REPO}  includedeb  precise ${LOCAL_SSL_SRC}/libssl0.9.8_0.9.8o-7ubuntu3.1_i386.deb

import_package                                                                                            libssl0.9.8_0.9.8k-7ubuntu8.14_amd64.deb
reprepro -T deb -V --ignore=wrongdistribution --basedir ${DEB_REPO}  includedeb  lucid   ${LOCAL_SSL_SRC}/libssl0.9.8_0.9.8k-7ubuntu8.14_amd64.deb
import_package                                                                                            libssl0.9.8_0.9.8k-7ubuntu8.14_i386.deb
reprepro -T deb -V --ignore=wrongdistribution --basedir ${DEB_REPO}  includedeb  lucid   ${LOCAL_SSL_SRC}/libssl0.9.8_0.9.8k-7ubuntu8.14_i386.deb

echo ""
echo "local openssl098 repo ready at ${DEB_REPO}"
echo ""
