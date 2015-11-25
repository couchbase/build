#!/usr/bin/python

import os
import sys
import signal
import logging
import json

from dashboard import Dashboard
from buildHistory import buildHistory, buildJob

from couchbase.bucket import Bucket
from couchbase.n1ql import N1QLQuery
from couchbase.views.params import Query
from couchbase.bucket import LOCKMODE_WAIT
from couchbase.exceptions import CouchbaseError, KeyExistsError, NotFoundError
from couchbase.views.iterator import RowProcessor


logger = logging.getLogger()

class buildDB(object):
    def __init__(self, bucket):
        self.bucket = bucket
        self.db = Bucket(bucket, lockmode=LOCKMODE_WAIT)

    def insert_job_history(self, job):
        #
        # param: job
        # type: dict
        #
        try:
            docId = job['branch']+"-"+str(job['buildNum'])+"-"+job['platform']+"-"+job['edition']
            result = self.db.insert(docId, job)
            logger.debug("{0}".format(result))
        except CouchbaseError as e:
            if e.rc == 12: 
                logger.warning("Couldn't create job history {0} due to error: {1}".format(docId, e))

        return docId

    def update_job_history(self, job):
        #
        # param: job
        # type: dict
        #
        try:
            docId = job['branch']+"-"+str(job['buildNum'])+"-"+job['platform']+"-"+job['edition']
            result = self.db.replace(docId, job)
            logger.debug("{0}".format(result))
        except CouchbaseError as e:
            if e.rc == 13: 
                logger.error("Couldn't update job history. {0} does not exist {1}".format(docId, e))
             
    def insert_build_history(self, bldHistory):
        #
        # param: bldHistory
        # type: dict
        #
        # Job history should be inserted prior to this
        #
        try:
            docId = bldHistory['branch']+"-"+str(bldHistory['buildNum'])
            result = self.db.insert(docId, bldHistory)
            logger.debug("{0}".format(result))
        except CouchbaseError as e:
            if e.rc == 12: 
                logger.warning("Couldn't create build history {0} due to error: {1}".format(docId, e))

        return docId

    def update_build_history(self, bldHistory):
        try:
            docId = bldHistory['branch']+"-"+str(bldHistory['buildNum'])
            result = self.db.replace(docId, bldHistory)
            logger.debug("{0}".format(result))
        except CouchbaseError as e:
            if e.rc == 13: 
                logger.error("Couldn't update build history {0} does not exist {1}".format(docId, e))

    def insert_commit(self, commit):
        try:
            docId = commit['repo']+"-"+str(commit['commitId'])
            result = self.db.insert(docId, commit)
            logger.debug("{0}".format(result))
        except CouchbaseError as e:
            if e.rc == 12: 
                logger.error("Couldn't create commit history {0} due to error: {1}".format(docId, e))

        return docId

    def query_commit(self, commitId):
        readResult = self.db.get(commitId)
        return readResult.value

    def find_prev_build(self, dashboard_name, criteria="undefined"):
        logger.debug("Not implemented")
        bldNum = 0
        return bldNum

    def retrieve_incomplete_builds(self, dashboard_name):
        # Get previously incomplete builds
        logger.debug("{0}...not implemented".format(dashboard_name))

    def query_buildHistory(self, bldHistory):
        docId = bldHistory['branch']+"-"+str(bldHistory['buildNum'])
        readResult = self.db.get(docId)
        return readResult.value

    def __repr__(self):
        return ("buildDB(history, num_jobs)".format(self))
