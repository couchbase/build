#!/usr/bin/python

import sys
import json
import logging
import collections
import time, datetime

logger = logging.getLogger()


class buildHistory(object):
    def __init__(self, params):

        """
        Parent history describing individual set of builds

        """
        self.version = params['version']
        self.build_num = params['build_num'] 
        self.timestamp = params['timestamp'] 
        self.branch = params['branch'] 
        self.release = params['release'] 
        self.released = params['released'] 
        self.manifest = params['manifest'] 
        self.manifest_sha = params['manifest_sha'] 
        self.jenkinsUrl = params['jenkinsUrl'] 
        self.jobType = params['jobType']
        self.commits = params['commits']
        self.repo_deleted = params['repo_deleted']
        self.passed = [] 
        self.failed = [] 
        self.sanity = [] 
        self.unitTest = [] 
        self.sanityResult = "" 
        self.unitTestResult = "" 
        self.result = params['result']
        if not params['duration']: 
            self.duration = 0
        else:
            self.duration = params['duration'] 

    def getVersion(self):
        return self.version

    def getBuildNum(self):
        return self.build_num

    def getResult(self):
        self.result

    def getDuration(self):
        self.duration

    def getPassedBuilds(self):
        return self.passed

    def getFailedBuilds(self):
        return self.failed

    def getUnitTest(self):
        return self.unitTest

    def getTimestamp(self):
        return self.timestamp

    def setTimestamp(self, timestamp):
        self.timestamp = timestamp

    def update_sanity_result(self, result):
        if not self.sanityResult or self.sanityResult != "failed":
            self.sanityResult = result

    def update_unitTest_result(self, result):
        if not self.unitTestResult or self.unitTestResult != "failed":
            self.unitTestResult = result

    def update_build_job_result(self, jobId, result, duration):
        if result == "passed":
            self.passed.append(jobId)
        else:
            self.failed.append(jobId)

        # Sum of all job durations -- BUG
        self.duration += duration

    def update_build_result(self, result, totalJobs):
        nJobs = len(self.failed) + len(self.passed)
        if totalJobs <= nJobs: 
            self.result = result 
        else:
            self.result = "incomplete" 
        return self.result

    def __repr__(self):
        return ("buildHistory (%s-%d)" % (self.version, self.build_num))
