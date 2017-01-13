#!/usr/bin/python

import sys
import json
import logging
from datetime import datetime

from util.buildHistory import buildHistory

logger = logging.getLogger()


class Dashboard(object):
    def __init__(self, params):

        """
        Dashboard per product branch

        :param name - name of the product
        """

        self.name = params['name']
        self.branch = params['branch']
        self.version = params['version']

        """
        :param mode
               push - build info and status delivered from Jenkins via message proxy (currently not supported)
               poll - proactively polling from buildboard server
        :param state
               idle - waiting for incoming builds 
               running - builds in progress
               completed - build (all jobs) finished 
        :param timeout (per build job)

        """

        self.state = 'idle'
        self.mode = params['mode']
        self.method = params['method']
        self.changeRequest = params['changeRequest']
        self.repo = params['githubParams']['repo']
        self.bldProject = params['githubParams']['project']
        self.pyGitRepo = None 
        self.parentUrl = params['jenkinsParams']['parentUrl'] 
        self.buildUrls = params['jenkinsParams']['buildUrls'] 
        self.unitTestUrls = params['jenkinsParams']['unitTestUrls'] 
        self.sanityUrls = params['jenkinsParams']['sanityUrls'] 
        self.gitType = params['githubParams']['type']
        self.manifest = params['githubParams']['manifest']
        self.githubRemotes = params['githubParams']['remotes']
        self.totalJobs = int(params['jenkinsParams']['buildJobs'])
        self.binPath = params['binPath']
        self.curBuildNum = 0
        self.curUnitTestBldNum = 0
        self.curSanityBldNum = 0
        self.timestamp = ""
        self.duration = 0
        self.buildResult = ""
        self.timeout = params['timeout']
        self.buildList = []
        self.unitTestList = []

        """
        :param buildResult (current in-build status)
               passed - all completed jobs are SUCCESS
               failed - one or more jobs failed
        """

    def getName(self):
        return self.name

    def getBranch(self):
        return self.branch

    def getVersion(self):
        return self.version

    def getBuildProject(self):
        return self.bldProject

    def getChangeRequestFrom(self):
        return self.changeRequest

    def getRepo(self):
        return self.repo

    def getGithubRemotes(self):
        return self.githubRemotes

    def getGitType(self):
        return self.gitType

    def getParentUrl(self):
        return self.parentUrl

    def getBuildUrl(self):
        return self.buildUrls

    def getUnitTestUrls(self):
        return self.unitTestUrls

    def getSanityUrls(self):
        return self.sanityUrls

    def getPendingUnitTest(self):
        return self.unitTestList

    def getManifest(self):
        return self.manifest

    def getState(self):
        return self.state

    def getMode(self):
        return self.mode

    def getMethod(self):
        return self.method

    def getCurBuildNum(self):
        return self.curBuildNum

    def getCurUnitTestBldNum(self):
        return self.curUnitTestBldNum

    def getCurSanityBldNum(self):
        return self.curSanityBldNum

    def getBuildResult(self):
        return self.buildResult

    def getBinPath(self):
        return self.binPath

    def getPyGitRepo(self):
        return self.pyGitRepo

    def setPyGitRepo(self, gitRepo):
        self.pyGitRepo = gitRepo

    def idle(self):
        if self.state != 'monitoring':
            self.state = 'idle'

    def scanning(self):
        if self.state != 'monitoring':
            self.state = 'scanning'

    def start_monitor(self):
        self.state = 'monitoring'

    def stop_monitor(self):
        if self.state != 'scanning':
            self.state = 'idle'

    def health_check(self, build):
        result = ""
        nJobs = len(build.getPassedBuilds()) + len(build.getFailedBuilds())
        if nJobs < self.totalJobs:
            result = 'pending'
# Need to fix this
#        if self.duration > self.timeout:
#            result = "timeout"
        return (result)

    def update_build_job_result(self, build, docId, bldResult, duration, testResults):
        # Check for issues such as hang
        # Determine the cause and force a stop with "incomplete" status
        if not bldResult:
            jobResult = 'unknown'
        elif bldResult == 'SUCCESS':
            jobResult = 'passed'
        else:
            jobResult = 'failed'

        # Dashboard buildResult indicates running status
        if not self.buildResult or self.buildResult != 'failed':
            self.buildResult = jobResult 

        if testResults['result']:
            if testResults['result'] == 'SUCCESS':
                build.update_unitTest_result('passed')
            else:
                build.update_unitTest_result('failed')

        build.update_build_job_result(docId, jobResult, duration)
        self.duration = build.getDuration()
        return jobResult

    def update_build_result(self, build):
        # Check for issues such as hang
        # Determine the cause and force a stop with "incomplete" status
        self.buildResult = build.update_build_result(self.buildResult, self.totalJobs)
        return self.buildResult

    def reset_build_result(self):
        self.buildResult = "" 

    def add_build(self, build):
        match = False
        for bld in self.buildList:
            if bld.getBuildNum() ==  build.getBuildNum():
                match = True
        if not match:
            self.buildList.append(build)

        # If starting with an empty queue 
        qlen = len(self.buildList)
        if qlen == 1:
            self.curBuildNum = build.getBuildNum()

        logger.debug("Total builds in queue {0}".format(qlen))
        return qlen

    def get_current_build(self):
        build = None
        for build in self.buildList:
            if self.curBuildNum == build.getBuildNum():
                break
        return build 

    def get_next_build(self):
        nextBldNum = 0
        # Remove current build first
        for build in self.buildList:
            if build.getBuildNum() == self.curBuildNum:
                self.buildList.remove(build)
                break

        if self.buildList: 
            nextBld = self.buildList[0] 
            if nextBld:
                nextBldNum = nextBld.getBuildNum() 
                self.curBuildNum = nextBldNum
        return nextBldNum

    def add_unitTest(self, unitTest):
        if unitTest in self.unitTestList:
            return len(self.unitTestList)

        self.unitTestList.append(unitTest)

        # If starting with an empty queue 
        qlen = len(self.unitTestList)
        if qlen == 1:
            self.curUnitTestBldNum = unitTest['build_num']

        logger.debug("Total unitTest in queue {0}".format(qlen))
        return qlen

    def update_unitTest(self, testResults):
        for test in self.unitTestList:
            if test['build_num'] == testResults['build_num']:
                self.unitTestList.remove(test)
                break
        if self.unitTestList and self.curUnitTestBldNum == testResults['build_num']:
            self.curUnitTestBldNum = self.unitTestList[0]['build_num'] 

    def advance_curUnitTestBldNum(self, buildNum):
        if self.curUnitTestBldNum < buildNum:
            self.curUnitTestBldNum = buildNum

    def close(self):
        # Check for pending jobs
        if self.buildList:
            logger.warning("Terminating Dashboard monitor jobs gracefully. Not yet implemented")

    def __repr__(self):
        return ("Dashboard (%s)" % self.name)
