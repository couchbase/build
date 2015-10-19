#!/usr/bin/python

import sys
import json
import signal
import logging
import collections
from datetime import datetime

logger = logging.getLogger()


class buildJob(object):
    def __init__(self, buildNum, jobUrl):

        """
        Actual Build job per target
        """

        self.buildNum = buildNum
        self.docId = ""
        self.branch = ""
        self.jenkinsUrl = jobUrl
        self.status = ""
        self.platform = ""
        self.edition = ""
        self.slave = ""
        self.duration = 0
        self.bldValidation = 0
        self.timestamp = 0

    def getStatus(self):
        return self.status

    def getDuration(self):
        self.duration

    def getTimestamp(self):
        self.timestamp

    def getDocId(self):
        return self.docId

    def getJenkinsUrl(self):
        return self.jenkinsUrl

    def setStatus(self, status):
        self.status = status

    def setDuration(self, duration):
        self.duration = duration

    def get_db_history(self):
        """
        :type: dict
        """
        history = {}
        history["buildNum"] = self.buildNum 
        history["branch"] = self.branch
        history["docId"] = self.docId 
        history["platform"] = self.platform
        history["edition"] = self.edition
        history["slave"] = self.slave
        history["status"] = self.status
        history["timestamp"] = self.timestamp
        history["duration"] = self.duration

        return history

    def update_db_history(self, history):
        """
        :type: dict
        """
        if "buildNum" in history:
            self.buildNum = history["buildNum"]
        if "status" in history:
            self.status = history["status"]
        if "unit_test" in history:
            self.unit_test = history["unit_test"]
        if "sanity_test" in history:
            self.sanity_test = history["sanity_test"]
        self.docId = history["docId"]
        self.branch = history["branch"]
        self.platform = history["platform"]
        self.edition = history["edition"]
        self.slave = history["slave"]
        self.duration = history["duration"]
        self.timestamp = history["timestamp"]

    def __repr__(self):
        return ("buildJob".format(self, self.branch))


class buildValidation(object):
    def __init__(self, buildNum, jenkinsUrl):

        """
        Build validation specifics

        :param type = "unit-test" or "sanity-test"
        """

        self.buildNum = buildNum
        self.branch = ""
        self.jenkinsUrl = jenkinsUrl
        self.status = "started"
        self.platform = ""
        self.edition = ""
        self.slave = ""
        self.timestamp = 0
        self.duration = 0
        self.type = None

    def __repr__(self):
        return ("buildValidation(buildNum)".format(self, self.branch))


class buildHistory(object):
    def __init__(self, buildNum, jenkinsUrl):

        """
        Overall history describing a general set of build

        """
        self.buildNum = 0
        self.codename = ""
        self.branch = ""
        self.jenkinsUrl = jenkinsUrl
        self.slave = ""
        self.status = ""
        self.duration = 0
        self.manifestSHA = 0
        self.changeSet = []
        self.bld_jobs = []
        self.bldJobs_docId = []
        self.bld_validation = []
        self.jobs_pending = 0
        self.test_pending = 0
        self.released = 0
        self.timestamp = 0

    def add_job(self, job):
        status = job.getStatus()
        if isinstance(job, buildJob):
            self.bld_jobs.append(job)
            self.bldJobs_docId.append(job.getDocId())
            if status == "" or status == "pending":
                self.jobs_pending += 1
        if isinstance(job, buildValidation):
            self.bld_validation.append(job)
            self.bldJobs_docId.append(job.getDocId())
            if status == "" or status == "pending":
                self.test_pending += 1

    def getBuildNum(self):
        return self.buildNum

    def getStatus(self):
        self.status

    def getDuration(self):
        self.duration

    def getTimestamp(self):
        return self.timestamp

    def getChangeSet(self):
        return self.changeSet

    def getNumJobsPending(self):
        return self.jobs_pending

    def setStatus(self, status):
        self.status = status

    def setTimestamp(self, timestamp):
        self.timestamp = timestamp

    def setDuration(self, duration):
        self.duration = duration

    def getBuildJobs(self):
        return self.bld_jobs

    def job_is_new(self, jobUrl):
        for job in self.bld_jobs:
            if job.getJenkinsUrl() == jobUrl:
                return False
        return True 

    def get_pending_jobs(self):
        pending_jobs = []
        for job in self.bld_jobs:
            status = job.getStatus()
            if status == "" or status == "pending":
                pending_jobs.append(job)
        return pending_jobs

    def get_db_history(self):
        """
        :type: dict
        """
        history = {}
        history["buildNum"] = self.buildNum 
        history["codename"] = self.codename 
        history["branch"] = self.branch
        history["slave"] = self.slave
        history["status"] = self.status
        history["changeSet"] = self.changeSet
        history["timestamp"] = self.timestamp
        history["duration"] = self.duration
        history["bldJobs_docId"] = self.bldJobs_docId

        return history

    def update_db_history(self, history):
        """
        :type: dict
        """
        if "buildNum" in history:
            self.buildNum = history["buildNum"]
        if "status" in history:
            self.status = history["status"]
        self.codename = history["codename"]
        self.branch = history["branch"]
        self.slave = history["slave"]
        self.changeSet = history["changeSet"]
        self.duration = history["duration"]
        self.timestamp = history["timestamp"]
        self.bldJobs_docId = history["bld_jobs"]
        self.bldJobs_docId = history["bldJobs_docId"]

    def __repr__(self):
        return ("buildHistory {0}".format(self, self.codename))
#         return "<%s at 0x%x: %s>" % (self.__class__.__name__, id(self), self)
