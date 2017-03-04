#!/bin/bash -e
#
#  Sign pacakges in local yum repo.  Step 4 of six:
#
#   1.  prepare repo meta-files
#   2.  seed new repo
#   3.  import and sign packages
#   4.  sign local repo
#   5.  upload local repo to shared repository
#   6.  upload keys and yum.repos.d
#
if [[ ! ${LOCAL_REPO_ROOT} ]] ; then  LOCAL_REPO_ROOT=~/linux_repos/couchbase-server ; fi

function usage
{
    echo ""
    echo "use:  `basename $0` Edition"
    echo ""
    echo "      Edition is either 'community' or 'enterprise'"
    echo ""
}

EDITION=$1 ; shift ; if [[ ! ${EDITION} ]] ; then read -p "Edition: "  EDITION ; fi
if [[ ${EDITION} != 'community' && ${EDITION} != 'enterprise' ]] ; then echo "bad edition" ; usage ; exit 9 ; fi

REPO=${LOCAL_REPO_ROOT}/${EDITION}/rpm

echo ""
echo "Signing local ${EDITION} repo at ${REPO}"
echo ""

RPM_GPG_KEY_V4=CD406E62

for CENTOS in 6 7
do
    createrepo --update  ${REPO}/${CENTOS}/x86_64
    gpg --batch --yes -u ${RPM_GPG_KEY_V4} --detach-sign --armor ${REPO}/${CENTOS}/x86_64/repodata/repomd.xml
done

echo ""
echo "Done signing ${EDITION} repo at ${REPO}"
echo ""
