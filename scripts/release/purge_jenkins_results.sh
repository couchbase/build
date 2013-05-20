#!/bin/bash

function usage
    {
    echo ""
    echo "use:  $0   job-name  from-bld  to-bld  username   api-token"
    echo ""
    echo "      will purge build results of job-name"
    echo "      builds from-bld to to-bld, inclusive"
    echo ""
    echo "To get your api-token log into jenkins and look at your settings."
    echo "You will see a string like: 34f1e3c181b49c483b2de6f2224cec21"
    echo ""
    exit 0
    }

TRUE=0
FALSE=1
INT_REX='^[0-9]+$'

BASE_URL=http://qa.hq.northscale.net

function isInt
    {
    value=$1

    if [[ $value =~ $INT_REX ]]
      then
        RANGE=${BASH_REMATCH[1]}
        echo $TRUE
      else
        echo $FALSE
    fi
    }


if [[ ! $5 ]] ; then usage ; fi

JOB_NAME=$1
FRST_BLD=$2
LAST_BLD=$3

USERNAME=$4
APITOKEN=$5

if [[ `isInt ${FRST_BLD}` != $TRUE ]] ; then echo "Not an integer: ${FRST_BLD}" ; usage ; fi
if [[ `isInt ${LAST_BLD}` != $TRUE ]] ; then echo "Not an integer: ${LAST_BLD}" ; usage ; fi

if [[ ${LAST_BLD} -lt ${FRST_BLD} ]]
    then
    echo swapping....
    SWAP_TMP=${LAST_BLD}
    LAST_BLD=${FRST_BLD}
    FRST_BLD=${SWAP_TMP}
fi

for (( BLD=${FRST_BLD} ; ${BLD} < ${LAST_BLD} ; BLD++ ))
    do
    echo "delete build ${BLD} of ${JOB_NAME}"
    
    curl --data "" --user ${USERNAME}:${APITOKEN} ${BASE_URL}/job/${JOB_NAME}/${BLD}/doDelete
    STATUS=$?
    if [[ ${STATUS} -gt 0 ]] ; then echo "FAILED: ${STATUS}" ; break ; fi
done

