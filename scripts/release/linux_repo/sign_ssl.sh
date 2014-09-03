#!/bin/bash
# 
#  Sign pacakges in local openssl098 yum repo.  Step 4 of five:
#  
#   1.  prepare local openssl098 repos
#   2.  seed new repos
#   3.  import packages
#   4.  sign RPM packges in local repos
#   5.  upload local repos to shared repository
#  
if  [[ ! ${LOCAL_SSL_ROOT} ]] ; then  LOCAL_SSL_ROOT=~/linux_repos/openssl098 ; fi

RPM_REPO=${LOCAL_SSL_ROOT}/rpm

function usage
    {
    echo ""
    echo "use:  `basename $0`"
    echo ""
    echo "signs the RPM packages in local openssl098 repo: ${RPM_REPO}"
    }

RPM_GPG_KEY_V4=805A4A3A
RPM_GPG_KEY_V3=EC0B64C2

echo ""
echo "Signing local openssl098 repo at ${RPM_REPO}"
echo ""

rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V3}"  ${RPM_REPO}/5/x86_64/openssl-0.9.8e-22.el5_8.4.i686.rpm
rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V3}"  ${RPM_REPO}/5/x86_64/openssl-0.9.8e-22.el5_8.4.x86_64.rpm
rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V3}"  ${RPM_REPO}/5/i386/openssl-0.9.8e-22.el5_8.4.i386.rpm
rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V3}"  ${RPM_REPO}/5/i386/openssl-0.9.8e-22.el5_8.4.i686.rpm

rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V4}"  ${RPM_REPO}/6/x86_64/openssl098e-0.9.8e-17.el6.centos.2.i686.rpm
rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V4}"  ${RPM_REPO}/6/x86_64/openssl098e-0.9.8e-17.el6.centos.2.x86_64.rpm
rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V4}"  ${RPM_REPO}/6/i386/openssl098e-0.9.8e-17.el6.centos.2.i686.rpm


gpg --batch --yes -u ${RPM_GPG_KEY_v3} --detach-sign --armor ${RPM_REPO}/5/x86_64/repodata/repomd.xml
gpg --batch --yes -u ${RPM_GPG_KEY_v3} --detach-sign --armor ${RPM_REPO}/5/i386/repodata/repomd.xml
gpg --batch --yes -u ${RPM_GPG_KEY_V4} --detach-sign --armor ${RPM_REPO}/6/x86_64/repodata/repomd.xml
gpg --batch --yes -u ${RPM_GPG_KEY_V4} --detach-sign --armor ${RPM_REPO}/6/i386/repodata/repomd.xml

echo ""
echo "Done signing openssl098 repo at ${RPM_REPO}"
echo ""
