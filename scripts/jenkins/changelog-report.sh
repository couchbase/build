#!/bin/bash

#### jenkins job:  changelog-report 
# 
# build parameters:
# 
# LAST_BLD   - build number of last build in survey period
# FIRST_BLD  - build number of first build in survey period
# 
# BRANCH     - which branch these changes occur on

PROJECTS="couchbase-cli couchdb couchdbx-app couchstore ep-engine geocouch membase.cli ns_server testrunner tlm"

FAILS=0

HTTP=http://builds.hq.northscale.net/latestbuilds

PKG_ROOT=couchbase-server-enterprise_x86_64

GITLOG='--pretty=format:--------------------------------------------------%ncommit: %H%nAuthor: %an < %ae >%nDate:   %cd%n%n%s%n%n%b'


REPORTS=${WORKSPACE}/${LAST_BLD}-${FIRST_BLD}
if [[ -d ${REPORTS} ]] ; then rm -rf ${REPORTS} ; fi
mkdir    ${REPORTS}


function fetch_manifest
    {
    bld_num=$1
    
    bld_num=`echo $bld_num  | sed 's/^ *//g' | sed 's/ *$//g'`

    branch=${BRANCH}
    if ( ${BRANCH} == 'master' ) ; then branch=2.1.0 ; fi
    
    pushd ${REPORTS} > /dev/null
    
    for sufx in deb rpm setup.exe
      do
      manifest=${PKG_ROOT}_${branch}-${bld_num}-rel.${sufx}.manifest.xml
      
      wget  ${HTTP}/${manifest}
      if [[ $? == 0 ]]
          then
          echo ${manifest}
          return 0
      fi
    done
    popd             > /dev/null
    return 99
    }

function get_rev
    {
    manifest=$1
    component=$2

    grep \"${component}\" ${REPORTS}/${manifest} | tr ' ' "\n" | grep revision | awk -F\" '{print $2}'
    }


echo ---------------------------------------------- cleaning workspace: ${WORKSPACE}
rm ${PKG_ROOT}*.manifest.xml

echo ---------------------------------------- getting manifest for build ${LAST_BLD}
MFST_1ST=`fetch_manifest ${LAST_BLD}`
if [[ $? > 0 ]]
    then
    echo ======== could not find manifest for build: ${BRANCH}-${LAST_BLD}
    exit 99
fi
echo ---------------------------------------- ${MFST_1ST}

echo ---------------------------------------- getting manifest for build ${FIRST_BLD}
MFST_2ND=`fetch_manifest ${FIRST_BLD}`
if [[ $? > 0 ]]
    then
    echo ======== could not find manifest for build: ${BRANCH}-${FIRST_BLD}
    exit 99
fi
echo ---------------------------------------- ${MFST_2ND}

echo -------------------------------------------- comparing manifests
echo ${MFST_1ST}
echo ${MFST_2ND}
echo -------------------------------------------- 


for COMP in ${PROJECTS}
  do
  if [[ -d ${COMP} ]]
    then
    echo ---------------------------------------------- ${COMP}

    OUT=${REPORTS}/${COMP}-changelog-${BRANCH}-${LAST_BLD}-${FIRST_BLD}.txt
    echo  ${COMP} changes between builds ${BRANCH}-${FIRST_BLD} and ${BRANCH}-${LAST_BLD}   > ${OUT}
    pushd ${COMP}  > /dev/null
    
    THIS_FAIL=0
    
    REV_1ST=`get_rev ${MFST_1ST} ${COMP}`
    REV_2ND=`get_rev ${MFST_2ND} ${COMP}`
    
    if [[ `git remote -v | grep -l changelog` ]]
      then git remote rm           changelog
    fi
    BASE=`git  remote -v | head -1 | awk '{print $1}'`
    
    git clean -dfx
    git remote add changelog  https://github.com/${BASE}/${COMP}.git
    echo --------
    git remote -v
    echo --------
    git fetch --all    ;    STATUS=$?

    if [[ $STATUS > 0 ]]
      then
           git fetch --all                                                                 >> ${OUT}
           THIS_FAIL=1
           echo FAILED to FETCH: ${COMP}
    else
      sleep 6
      if  [[ ! `git branch --all | grep changelog | grep ${BRANCH}` ]]
          then 
          echo Project ${COMP} has no branch ${BRANCH} on github
          echo Project ${COMP} has no branch ${BRANCH} on github                           >> ${OUT}
      else
          RANGE="${REV_2ND}..${REV_1ST}"
          if [[  ${REV_2ND} == ${REV_1ST} ]]
              then
              echo No changes: both builds use revision ${REV_1ST}
              echo No changes: both builds use revision ${REV_1ST}                         >> ${OUT}
          else
              echo    git log --max-count=128 --name-status ${RANGE}
              echo    git log ${RANGE}                                                     >> ${OUT}
              echo    ----------------------------------------------------------           >> ${OUT}
              echo    ----------------------------------------------------------
              git log --max-count=128 "${GITLOG}" --name-status ${RANGE}
              STATUS=$?
              
              if [[ $STATUS > 0 ]]
                  then
                  THIS_FAIL=1
                  echo FAILED to LOG: ${COMP}/${BRANCH}
              else
                  echo logged changes: ${COMP}${BRANCH}
                  echo in:             ${OUT}
                  git log --max-count=128 "${GITLOG}" --name-status ${RANGE}  2>&1         >> ${OUT}
              fi
          fi
      fi
    fi
    
    if [[ ${THIS_FAIL} > 0 ]] ; then let FAILS++ ; fi
    
    git remote rm  changelog
    echo --------
    popd           > /dev/null
    sleep 10
  else
    echo ------------ NO SUCH DIRECOTRY --------------- ${COMP}
  fi
done


if [[ ${FAILS} > 0 ]] ; then echo ${FAILS} tests FAILED
else
    echo All Tests Passed
fi
exit  ${FAILS}
