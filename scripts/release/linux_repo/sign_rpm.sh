#!/bin/bash
#  
#  Sign pacakges in local yum repo.  Step 4 of six:
#  
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import packages
#   4.  sign packges in local repo
#   5.  upload local repo to shared repository
#   6.  upload keys and yum.repos.d
#  
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi

function usage
    {
    echo ""
    echo "use:  `basename $0`  Release Edition"
    echo ""
    echo "      Release is build number, like 2.0.2-1234"
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
    }

function get_version_base
    {
    local __result_rel_num=$1
    local __result_bld_num=$2
    
    local versionarg=$3
    local rel_num
    local bld_num
    
    vrs_rex='([0-9]\.[0-9]\.[0-9])-([0-9]{1,})'
    
    if [[ $versionarg =~ $vrs_rex ]]
      then
        for N in 1 2 ; do
            if [[ $N -eq 1 ]] ; then rel_num=${BASH_REMATCH[$N]} ; fi
            if [[ $N -eq 2 ]] ; then bld_num=${BASH_REMATCH[$N]} ; fi
        done
      else
        echo ""
        echo 'bad version >>>'${versionarg}'<<<'
        usage
        exit
    fi
    
    eval $__result_rel_num="'$rel_num'"
    eval $__result_bld_num="'$bld_num'"
    }

VERSION=$1 ; shift ; if [[ ! ${VERSION} ]] ; then read -p "Release: "  VERSION ; fi

get_version_base BASEVER BLDNUM ${VERSION}


EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[   ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi

REPO=${LOCAL_REPO_ROOT}/${EDITION}/rpm

echo ""
echo "Signing local ${EDITION} repo at ${REPO}"
echo ""

RPM_GPG_KEY_V4=CB6EBC87
RPM_GPG_KEY_V3=EC0B64C2

rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V3}" ${REPO}/5/i386/couchbase-server-community_${BASEVER}.x86_64.rpm 
rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V3}" ${REPO}/5/i386/couchbase-server-community_${BASEVER}.i386.rpm
rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V4}" ${REPO}/6/i386/couchbase-server-community_${BASEVER}.x86_64.rpm 
rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY_V4}" ${REPO}/6/i386/couchbase-server-community_${BASEVER}.i386.rpm 

gpg --batch --yes -u ${RPM_GPG_KEY_v3} --detach-sign --armor ${REPO}/5/x86_64/repodata/repomd.xml
gpg --batch --yes -u ${RPM_GPG_KEY_v3} --detach-sign --armor ${REPO}/5/i386/repodata/repomd.xml
gpg --batch --yes -u ${RPM_GPG_KEY_V4} --detach-sign --armor ${REPO}/6/x86_64/repodata/repomd.xml
gpg --batch --yes -u ${RPM_GPG_KEY_V4} --detach-sign --armor ${REPO}/6/i386/repodata/repomd.xml

echo ""
echo "Done signing ${EDITION} repo at ${REPO}"
echo ""
