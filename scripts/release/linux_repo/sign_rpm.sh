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

if [[ $1 == "--init" ]]
    then
   rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY}" /home/buildbot/couchbase-server/linux/rpm/5/i386/couchbase-server-community_2.0.0.x86_64.rpm 
   rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY}" /home/buildbot/couchbase-server/linux/rpm/5/i386/couchbase-server-community_2.0.0.i386.rpm
   rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY}" /home/buildbot/couchbase-server/linux/rpm/6/i386/couchbase-server-community_2.0.0.x86_64.rpm 
   rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY}" /home/buildbot/couchbase-server/linux/rpm/6/i386/couchbase-server-community_2.0.0.i386.rpm 

else if [[ $1 == "--update" ]]
    then
    rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY}" /home/buildbot/couchbase-server/linux/rpm/5/x86_64/couchbase-server-community_2.0.1.x86_64.rpm 
    rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY}" /home/buildbot/couchbase-server/linux/rpm/5/i386/couchbase-server-community_2.0.1.i386.rpm
    rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY}" /home/buildbot/couchbase-server/linux/rpm/6/x86_64/couchbase-server-community_2.0.1.x86_64.rpm 
    rpm --resign -D "_signature gpg" -D "_gpg_name ${RPM_GPG_KEY}" /home/buildbot/couchbase-server/linux/rpm/6/i386/couchbase-server-community_2.0.1.i386.rpm 
    else
        echo "use:  $0  --init | --update"
        exit 9
    fi
fi

gpg --batch --yes -u ${RPM_GPG_KEY} --detach-sign --armor /home/buildbot/couchbase-server/linux/rpm/5/x86_64/repodata/repomd.xml
gpg --batch --yes -u ${RPM_GPG_KEY} --detach-sign --armor /home/buildbot/couchbase-server/linux/rpm/5/i386/repodata/repomd.xml
gpg --batch --yes -u ${RPM_GPG_KEY} --detach-sign --armor /home/buildbot/couchbase-server/linux/rpm/6/x86_64/repodata/repomd.xml
gpg --batch --yes -u ${RPM_GPG_KEY} --detach-sign --armor /home/buildbot/couchbase-server/linux/rpm/6/i386/repodata/repomd.xml
