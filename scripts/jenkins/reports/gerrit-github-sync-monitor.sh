#!/bin/bash
#          
#          run by jenkins job 'gerrit-github-sync-monitor'
#          
#          with no paramters
#          
set -e

GITLOG='--pretty=format:--------------------------------------------------%ncommit: %H%nAuthor: %an < %ae >%nDate:   %cd%n%n%s%n%n%b'

PROJECTS='bucket_engine cbsasl couchbase-cli couchbase-examples couchbase-python-client
          couchdb couchdbx-app couchstore ep-engine geocouch healthchecker libconflate
          libvbucket moxi ns_server portsigar sigar testrunner tlm'

MEMPROJS='libmemcached memcached'

BRANCHES='master 2.5.0 2.2.0 2.1.1 for-rackspace

echo cleaning workspace: ${WORKSPACE}
rm ${WORKSPACE}/*.txt

FAILS=0

function compute_log
    {
    local BRAN=$1
    local REPO=$2
    local BASE=$3

    if [[ -d ${REPO} ]] ; then rm -rf ${REPO} ; fi
    echo =================================================  ${REPO} === ${BRAN}
    git clone https://github.com/${BASE}/${REPO}.git  ${REPO} 
    pushd ${REPO}  > /dev/null
        
    THIS_FAIL=0
        
    if [[ `git remote -v | grep -l gerrit_sync_monitor` ]]
      then git remote rm           gerrit_sync_monitor
    fi
    if [[ `git remote -v | grep -l github_sync_monitor` ]]
      then git remote rm           github_sync_monitor
    fi
        
    git clean -dfx
    git remote add gerrit_sync_monitor  ssh://review.couchbase.org:29418/${REPO}.git
    git remote add github_sync_monitor  https://github.com/${BASE}/${REPO}.git
    echo --------
    git remote -v
    echo --------    
    git fetch --all    ;    STAT=$?
        
    if [[ $STAT > 0 ]]
      then
          OUT=${WORKSPACE}/${REPO}.git_FAILED_to_fetch.${BRAN}.txt
          git fetch --all > ${OUT}
          THIS_FAIL=1
          echo FAILED to FETCH: ${REPO}
    else
      sleep 6
      if      [[ ! `git branch --all | grep gerrit_sync_monitor | grep ${BRAN}` ]]
          then
          OUT=${WORKSPACE}/${REPO}.gerrit_no_branch.${BRAN}.txt
          echo Project ${REPO} has no branch ${BRAN} on gerrit
          echo Project ${REPO} has no branch ${BRAN} on gerrit > ${OUT}
      
      else if [[ ! `git branch --all | grep github_sync_monitor | grep ${BRAN}` ]]
          then
          OUT=${WORKSPACE}/${REPO}.github_no_branch.${BRAN}.txt
          echo Project ${REPO} has no branch ${BRAN} on github
          echo Project ${REPO} has no branch ${BRAN} on github > ${OUT}
      else
          RANGE=github_sync_monitor/${BRAN}..gerrit_sync_monitor/${BRAN}
          git log --max-count=128 "${GITLOG}" --name-status ${RANGE} ; STATUS=$?
          if [[ $STATUS >0 ]]
            then
              sleep 6
              OUT=${WORKSPACE}/${REPO}.git_FAILED_to_log.${BRAN}.txt
              THIS_FAIL=1
              echo FAILED to LOG: ${REPO}/${BRAN}
            else
              OUT=${WORKSPACE}/${REPO}.git_DIFF_log.${BRAN}.txt
          fi
          git log --max-count=128 "${GITLOG}" --name-status ${RANGE} > ${OUT}
          if [[ `wc -c ${OUT} | awk '{print $1}'` == 0 ]] ; then rm ${OUT} ; fi
        fi
      fi
    fi
        
    if [[ ${THIS_FAIL} > 0 ]] ; then let FAILS++ ; fi
    
    git remote rm  gerrit_sync_monitor
    git remote rm  github_sync_monitor
    echo --------
    git remote -v
    echo --------
    popd           > /dev/null

    sleep 10
    }

for BRANCH in master  2.5.0  3.0.0  master
  do
  echo ==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+==  ${BRANCH}
  sleep 5
  for COMP in ${PROJECTS}
    do
      compute_log ${BRANCH} ${COMP}  couchbase
  done
  sleep 5
  for COMP in ${MEMPROJS}
    do
      compute_log ${BRANCH} ${COMP}  membase
  done
done

if [[ ${FAILS} > 0 ]] ; then echo ${FAILS} tests FAILED
else
    echo All Tests Passed
    echo All Tests Passed >> ${WORKSPACE}/ALL_IN_SYNC.git.txt
fi
exit  ${FAILS}
