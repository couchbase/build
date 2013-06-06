#!/bin/bash
#  
#  used to apply a tag to git repo

TAGNAME=2.0.2r
TAG_MSG='2.0.2-821.manifest.xml'

THISDIR=`pwd`
MANIFEST=${THISDIR}/2.0.2-821.manifest.xml

echo MANIFEST is $MANIFEST

WORKSPACE=add_tag_workspace

function get_version
    {
    local __result_repobase=$1
    local __result_revision=$2
    
    local inputline=$3
    local repobase
    local revision
    
    BASEREX='remote=\"([a-zA-Z_.-]*)\"'
    REV_REX='revision=\"([a-z0-9]*)\"'
    
    if [[ $inputline =~ $BASEREX ]]
      then
        for N in 1 2 ; do
            if [[ $N -eq 1 ]] ; then repobase=${BASH_REMATCH[$N]} ; fi
        done
      else
        repobase=couchbase
    fi
    if [[ $inputline =~ $REV_REX ]]
        then
        for N in 1 2 ; do
            if [[ $N -eq 1 ]] ; then revision=${BASH_REMATCH[$N]} ; fi
        done
    fi
    eval $__result_repobase="'$repobase'"
    eval $__result_revision="'$revision'"
    }

proj_count=1

function tag_project
    {
    PROJ=$1
    
    if [[ ! ${PROJ} ]] ; then echo "use:  tag_project <project>  [ <repo-base> ]"
    else
        PROJ_LINE=`grep name=\"${PROJ}\" ${MANIFEST} | grep path | grep -v remote=\"erlang\"`
        
        get_version  BASE  REVISION  "${PROJ_LINE}"
        
        if [[ ! ${BASE} ]]
          then    
            echo ================ CANNOT determine base ${BASE} =========
          else
            echo ======================================== initializing workspace for ${BASE}/${PROJ}
            if [[ -d ${PROJ} ]] ; then rm -rf ${PROJ} ; fi
            
            git clone https://github.com/${BASE}/${PROJ}.git  ;  STATUS=$?
            
            if [[ $STATUS -gt 0 ]] ; then echo "FAILED to clone ${BASE}/${PROJ}"
            else
                pushd ${PROJ}     > /dev/null
                if [[ ${REVISION} ]]
                  then    
                    if [[ `git tag | grep ${TAGNAME}` ]] ; then echo "${TAGNAME} already exists on ${PROJ}"
                    else
                        echo ........... git tag -m "${TAG_MSG}" ${TAGNAME}  ${REVISION}
                                         git tag -m "${TAG_MSG}" ${TAGNAME}  ${REVISION}
                        git push origin ${TAGNAME}
                        project_tally_name[$proj_count]=${PROJ}
                        project_tally_rvsn[$proj_count]=${REVISION}
                    fi
                  else
                    echo ============ CANNOT TAG ${BASE}/${PROJ} ============
                fi
                popd              > /dev/null
            fi
        fi
        echo ========================================
        let proj_count++
    fi
    }

rm -rf ${WORKSPACE}
mkdir  ${WORKSPACE}
pushd  ${WORKSPACE}   > /dev/null

for PP in `grep name=\" ${MANIFEST}  | grep path | grep -v remote=\"erlang\" | awk -F\" '{print $2}' | sort`
  do
    echo tag_project ${PP}
    tag_project ${PP}
done
popd                  > /dev/null


for (( ii=1 ; $ii < $proj_count ; ii++ ))
    do
    echo "${project_tally_rvsn[$ii]}    ${project_tally_name[$ii]}"
done
