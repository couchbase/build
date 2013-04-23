#!/bin/bash

#### build parameters
# 
# BRANCH_SRC=2.0.2
# BRANCH_DST=master
# PROJECTS="bucket_engine couchbase-examples couchbase-python-client couchbase-cli couchdb couchdbx-app couchstore ep-engine geocouch libconflate libvbucket membase-cli memcached ns_server portsigar sigar testrunner tlm"

echo ==========================================================================================
env
echo ==========================================================================================

GIT_URL=git://builds.hq.northscale.net

REPORT_ROOT=reports

REPDIR=not_merged
ERRDIR=git_errors
UPTDIR=up_to_date

REPORTS=${WORKSPACE}/${REPORT_ROOT}/${REPDIR}
ERRRORS=${WORKSPACE}/${REPORT_ROOT}/${ERRDIR}
UP2DATE=${WORKSPACE}/${REPORT_ROOT}/${UPTDIR}
echo ------------------------------------------------- cleaning: ${WORKSPACE}/${REPORT_ROOT}
rm -rf ${REPORT_ROOT}
mkdir  ${REPORT_ROOT}

NOTIFY_GOOD=${WORKSPACE}/${REPORT_ROOT}/email_ok.txt
NOTIFY_TODO=${WORKSPACE}/${REPORT_ROOT}/email_to_merge.txt

FAILS=0


GITLOG='--pretty=format:--------------------------------------------------%ncommit: %H%nAuthor: %an < %ae >%nDate:   %cd%n%n%s%n%n%b'
GITLOG='--pretty=format:--------------------------------------------------\ncommit: %H\nAuthor: %an < %ae >\nDate:   %cd\n\n%s\n\n%b'


GIT_BASE=origin

function show_merges
    {
    local RSP
    local STATUS
    local MERGE
    
    RSP=`git checkout -b ${BRANCH_SRC} ${GIT_BASE}/${BRANCH_SRC}  2>&1`  ;  STATUS=$?
    if [[ $STATUS > 0 ]]
        then
        echo GIT ERROR: Failed to create local branch ${BRANCH_SRC}
        echo "${RSP}"
        return $STATUS
    fi
    if [[ ${BRANCH_DST} == master ]]
      then
        RSP=`git checkout                              ${BRANCH_DST}  2>&1`  ;  STATUS=$?
      else
        RSP=`git checkout -b ${BRANCH_DST} ${GIT_BASE}/${BRANCH_DST}  2>&1`  ;  STATUS=$?
    fi
    if [[ $STATUS > 0 ]]
        then
        echo GIT ERROR: Failed to create local branch ${BRANCH_DST}
        echo "${RSP}"
        return $STATUS
    fi
    
    sleep 6
    MERGE=`git merge --no-commit -s ours --verbose ${BRANCH_SRC}  2>&1`  ;  STATUS=$?
    
    if [[ ${MERGE} =~ 'Already up-to-date.' ]]
        then
        echo up-to-date
        return 0
    fi
    REGEX='Updating ([a-z0-9]*\.\.[a-z0-9]*)'
    if [[ ${MERGE} =~ $REGEX ]]
        then
        RANGE=${BASH_REMATCH[1]}
        MERGE=`git log "${GITLOG}" --name-status ${RANGE}  2>&1`  ;  STATUS=$?
        if [[ $STATUS > 0 ]]
          then 
            echo GIT ERROR:  unable to produce git log ${RANGE}
            echo "${MERGE}"
            return $STATUS
          else
            echo "${MERGE}"
            return 0
        fi
    fi
    if [[ ${MERGE} =~ 'Automatic merge went well' ]]
        then
        RANGE=${GIT_BASE}/${BRANCH_DST}..${GIT_BASE}/${BRANCH_SRC}
        MERGE=`git log "${GITLOG}" --name-status ${RANGE}  2>&1`  ;  STATUS=$?
        if [[ $STATUS > 0 ]]
          then 
            echo GIT ERROR:  unable to produce git log ${RANGE}
            echo "${MERGE}"
            return $STATUS
          else
            echo "${MERGE}"
            return 0
        fi
    fi
    if [[ $STATUS > 0 ]]
      then
        echo GIT ERROR:  unable to merge ${BRANCH_SRC} onto ${BRANCH_DST}
        echo "${MERGE}"
        return $STATUS
      else
        echo "${MERGE}"
        return 0
    fi
    }

function write_log
    {
    LOG_DIR=$1
    LOGFILE=$2
    LOG_MSG=$3
    
    OPT_ARG="";  if [[ $4 ]] ; then OPT_ARG=$4 ; fi
    
    if [[ ! -d ${LOG_DIR} ]]
        then
        mkdir  ${LOG_DIR}
        echo ---------------------------------------------------- mkdir: ${LOG_DIR}
    fi                    
    echo  ${OPT_ARG}  "${LOG_MSG}">> ${LOG_DIR}/${LOGFILE}
    echo  ${OPT_ARG}  "${LOG_MSG}"
    }


for COMP in ${PROJECTS}
  do
    if [[ -d ${COMP} ]]  ;  then rm -rf ${COMP} ; fi
    
 #  BASE=couchbase
 #  if [[ ${COMP} == membase-cli ]] ; then BASE=membase ; fi
 #  if [[ ${COMP} == memcached   ]] ; then BASE=membase ; fi

    echo ---------------------------------------------- ${COMP}
    OUT=${COMP}-GIT-ERROR.txt
    
    MSG=`git clone  ${GIT_URL}/${COMP}.git 2>&1`  ;  STATUS=$?
    
    if [[ $STATUS > 0 ]]
      then
        write_log              ${ERRRORS}  ${OUT}  "GIT ERROR: unable to clone ${GIT_URL}/${COMP}.git"
        THIS_FAIL=$STATUS
      else
        echo "clone ready: ${GIT_URL}/${COMP}.git"

        pushd ${COMP}  > /dev/null
    
        MSG=`git fetch --all 2>&1`  ;  STATUS=$?

        echo -----------
        echo merging from: ${BRANCH_SRC}
        echo merging   to: ${BRANCH_DST}
        echo -----------
        git branch --all
        echo -----------
        
        if [[ $STATUS > 0 ]]
          then
            write_log          ${ERRRORS}  ${OUT}  "GIT ERROR: unable to fetch ${COMP}\n${MSG}"  '-n'
            THIS_FAIL=$STATUS
          else
            sleep 3
            if      [[ ! `git branch --all | grep  ${GIT_BASE} | grep ${BRANCH_SRC}` ]]
              then
                write_log      ${ERRRORS}  ${OUT}  "Project ${COMP} has no branch ${BRANCH_SRC} on github"
                THIS_FAIL=0
              else
                if  [[ ! `git branch --all | grep  ${GIT_BASE} | grep ${BRANCH_DST}` ]]
                  then
                    write_log  ${ERRRORS}  ${OUT}  "Project ${COMP} has no branch ${BRANCH_DST} on github"
                    THIS_FAIL=0
                  else
                    MSG=`show_merges`    ;  THIS_FAIL=$?
                fi
            fi
        fi
        if [[ ${THIS_FAIL} > 0 ]]
          then
            let FAILS++
            OUT_DIR=${ERRRORS}
            OUTFILE=${OUT}
            OUT_ARG=''
          else
            if [[ ${MSG} =~ 'up-to-date' ]]
              then
                echo "debug:::: up-to-date"
                OUT_DIR=${UP2DATE}
                OUTFILE=${COMP}-UP-TO-DATE.txt
                OUT_ARG='-e'
                echo -e  ${COMP}                                                                  >>   ${NOTIFTY_GOOD}
                git log --oneline --graph --no-abbrev-commit --pretty="format:%H  %ci  %s" -1     >>   ${NOTIFTY_GOOD}
              else
                OUT_DIR=${REPORTS}
                OUTFILE=${COMP}-merge_report-${BRANCH_SRC}-${BRANCH_DST}.txt
                OUT_ARG='-e'
            fi
        fi
        write_log  ${OUT_DIR}  ${OUTFILE}  "${COMP} merge ${BRANCH_SRC} into ${BRANCH_DST}"                ${OUT_ARG}
        write_log  ${OUT_DIR}  ${OUTFILE}  "------------------------------------------------------------"
        write_log  ${OUT_DIR}  ${OUTFILE}  "[${BRANCH_DST}]  git merge --no-commit -s ours ${BRANCH_SRC}"
        write_log  ${OUT_DIR}  ${OUTFILE}  "------------------------------------------------------------"
        write_log  ${OUT_DIR}  ${OUTFILE}  "${MSG}"                                                        ${OUT_ARG}
        echo ${COMP} ${MSG}                                                                       >>   ${NOTIFY_TODO}
        popd           > /dev/null
        sleep 7
    fi
done


if [[ ${FAILS} > 0 ]] ; then echo ${FAILS} tests FAILED
else
    echo All Tests Passed
fi
exit  ${FAILS}
