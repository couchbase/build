#!/usr/bin/python

import os
import logging
import time
from datetime import datetime

from couchbase.bucket import Bucket
from couchbase.n1ql import N1QLQuery
from couchbase.views.params import Query
from couchbase.bucket import LOCKMODE_WAIT
from couchbase.exceptions import CouchbaseError, KeyExistsError, NotFoundError
from couchbase.views.iterator import RowProcessor

logger = logging.getLogger()

BUILDHISTORY_BUCKET = 'couchbase://buildboard-db:8091/build-history'
db = Bucket(BUILDHISTORY_BUCKET, lockmode=LOCKMODE_WAIT)

def db_doc_exists(docId):
    result = {} 
    try:
        result = db.get(docId)
    except CouchbaseError as e:
        return False
    return result

def db_insert(docId, doc):
    res = True
    try:
        result = db.insert(docId, doc)
        logger.debug("Insert {0} {1}".format(docId, result))
    except CouchbaseError as e:
        if e.rc == 12: 
            logger.error("Couldn't insert docID {0} due to error: {1}".format(docId, e))
        res = False
    return res

def db_upsert(docId, doc):
    res = True
    try:
        result = db.upsert(docId, doc)
        logger.debug("Upsert {0} {1}".format(docId, result))
    except CouchbaseError as e:
        if e.rc == 13: 
            logger.error("Attempt: {0} Couldn't update docId {1} does not exist {2}".format(retry, docId, e))
        res = False
    return res

def db_insert_build_history(build):
    res = True
    docId = build['version']+"-"+str(build['build_num'])
    res = db_insert(docId, build)
    if not res:
        docId = ""
        logger.error("Failed to insert build history {0}".format(docId))
    return docId

def db_insert_job_history(job):
    res = True
    docId = job['version']+"-"+str(job['build_num'])+"-"+job['distro']+"-"+job['edition']
    res = db_insert(docId, job)
    if not res:
        docId = ""
        logger.error("Failed to insert job history {0}".format(docId))
    return docId

def db_insert_test_history(test):
    res = True
    if 'edition' not in test:
        docId = test['version']+"-"+str(test['build_num'])+"-"+test['distro']+'-'+test['jobType']
    else:
        docId = test['version']+"-"+str(test['build_num'])+"-"+test['distro']+"-"+test['edition']+'-'+test['jobType']
    res = db_insert(docId, test)
    if not res:
        docId = ""
        logger.error("Failed to insert test history {0}".format(docId))
    return docId

# Needs to handle multiple 'in_build' per commit
def db_insert_commit(commit):
    docId = commit['repo']+"-"+str(commit['sha'])
    build = commit['in_build'][0]
    doc = db_doc_exists(docId)
    if doc:
        commits = doc.value
        if not build in commits['in_build']:
            commits['in_build'].append(build)
            res = db_upsert(docId, commits)
            if not res:
                docId = ""
                logger.error("Failed to upsert test history {0}".format(docId))
    else:
        res = db_insert(docId, commit)
        if not res:
            docId = ""
            logger.error("Failed to insert test history {0}".format(docId))
    return docId

def db_update_build_job_result(docId, jobResult, duration, unitTestId):
    doc = db_doc_exists(docId)
    if doc:
        bldHistory = doc.value
        bldHistory['result'] = jobResult 
        bldHistory['duration'] = duration 
        if unitTestId:
            bldHistory['unitTest'].append(unitTestId)
        doc = db_upsert(docId, bldHistory)
        logger.debug("Upsert {0} {1}".format(docId, doc))
    else:
        return False
    return True

def db_update_build_result(build, result):
    docId = build.getVersion() + '-' + str(build.getBuildNum())

    doc = db_doc_exists(docId)
    if doc:
        bldHistory = doc.value
        bldHistory['result'] = result 
        bldHistory['duration'] = build.getDuration() 
        bldHistory['passed'] = build.getPassedBuilds() 
        bldHistory['failed'] = build.getFailedBuilds() 
        result = db_upsert(docId, bldHistory)
        logger.debug("Upsert {0} {1}".format(docId, result))
    else:
        return False
    return True

def db_build_attach_unitTest(unitTestId, edition):
    doc = db_doc_exists(unitTestId)
    if doc:
        hist = doc.value
        version = hist['version']
        buildNum = hist['build_num']
        distro = hist['distro']


        docId = version+'-'+str(buildNum)+'-'+distro+'-'+edition
    #    query = "UPDATE `build-history` USE KEYS '{0}' SET unitTest='{1}'".format(docId, unitTestId) 
    #    q = N1QLQuery(query)
    #    db.n1ql_query(q)
        doc = db_doc_exists(docId)
        if doc:
            hist = doc.value
            hist['unitTest'] = unitTestId
            result = db_upsert(docId, hist)
            logger.debug("Upsert {0} {1}".format(docId, result))
        logger.debug("Upsert {0}".format(docId))

        docId = version+'-'+str(buildNum)
        doc = db_doc_exists(docId)
        if doc:
            hist = doc.value
            if unitTestId not in hist['unitTest']:
                hist['unitTest'].append(unitTestId)
                result = db_upsert(docId, hist)
                logger.debug("Upsert {0} {1}".format(docId, result))

    return True

def db_update_test_result(test):
    res = True
    if 'edition' not in test:
        docId = test['version']+'-'+str(test['build_num'])+'-'+test['distro']+'-'+test['jobType'] 
    else:
        docId = test['version']+'-'+str(test['build_num'])+'-'+test['distro']+'-'+test['edition']+'-'+test['jobType'] 
    doc = db_doc_exists(docId)
    if doc:
        testHistory = doc.value
        testHistory['result'] = results['result']
        testHistory['duration'] = results['duration']
        res = db_upsert(docId, testHistory)
        if not res:
            docId = ""
            logger.error("Failed to update test history {0}".format(docId))
    return docId

def db_get_builds_by_type(version, type='parent_build', limit=1, startBldNum=0):
    #
    # Get n(limit) builds from "startBldNum" for a particular type
    # Default to the latest parent build
    #
    rows = []
    buildList = []

    if startBldNum > 1:
        query = "SELECT * FROM `build-history` WHERE version='{0}' AND jobType='{1}' AND build_num BETWEEN {2} AND {3} ORDER BY distro".format(version, type, startBldNum+limit-1, startBldNum)
    else:
        query = "SELECT * FROM `build-history` WHERE version='{0}' AND jobType='{1}' ORDER BY build_num DESC LIMIT {2}".format(version, type, limit)

    q = N1QLQuery(query)
    rows = db.n1ql_query(q)
    for row in rows:
        buildList.append(row['build-history'])
    return buildList

def db_get_builds_by_number(version, buildNum):
    #
    # Get all jobs in a particular build
    #
    rows = []
    buildList = []

    query = "SELECT * FROM `build-history` WHERE version='{0}' AND build_num={1} ORDER BY distro".format(version, buildNum)
    q = N1QLQuery(query)
    rows = db.n1ql_query(q)
    for row in rows:
        buildList.append(row['build-history'])
    return buildList

def db_get_incomplete_builds():
    q = N1QLQuery("SELECT url from `build-history` WHERE jobType = 'parent_build' and result = 'incomplete'")
    urls = []
    for row in db.n1ql_query(q):
        urls.append(row['jenkinsUrl'])
    return urls


#########################
# REST API support
#########################

def db_get_last_successful_build(version):
    builds = []
    q = N1QLQuery("SELECT max(build_num) FROM `build-history` WHERE version = '{0}' AND jobType = 'parent_build' AND result = 'passed'".format(version))
    rows = db.n1ql_query(q)
    for row in rows:
        builds.append(row['$1'])
        break
    if builds:
        return builds[0]
    else:
        return 0

