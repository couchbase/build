#!/usr/bin/python

import sys
import json
import logging
from datetime import datetime

from buildHistory import buildHistory, buildJob

logger = logging.getLogger()


class Dashboard(object):
    def __init__(self, name, params):

        """
        Dashboard per product branch

        :param name - name of the product/branch
        """

        self.name = name

        """
        :param method
               push - build info and status delivered from Jenkins via message proxy (currently not supported)
               pull - proactively polling from buildboard server
        :param state (running)
               starting - initializing 
               ready - start accepting request (new builds/jobs)
               running - monitoring active builds/jobs 
               finish - build (all jobs) finished 
               suspend - stop monitoring
               stop - stop accepting build request
               close - shudownn
        :param timeout (per build job)

        """

        self.state = "starting"
        self.method = params["method"]
        self.dashboardColor = "" 
        self.htmlDashboard = ""
        self.htmlBuildHistory = ""
        self.jenkinsParentUrl = params["jenkinsParentUrl"] 
        self.jenkinsBuildUrls = params["jenkinsBuildUrls"] 
        self.jenkinsType = params["jenkinsType"]
        self.githubUrl = params["githubUrl"] 
        self.githubType = params["githubType"]
        self.timeout = params["timeout"]
        self.timestamp = 0
        self.runningTime = 0
        self.bldDuration = 0
        self.bldDuration_min = 0
        self.bldDuration_max = 0
        self.currBuildNum = 0
        self.prevBuildNum = 0
        self.buildStatus = "pending"
        self.nCommits = 0
        self.lastSuccessfulBuild = 0
        self.lastSuccessfulValidation = 0
        self.job_queue = []
        self.watch_queue = []
        self.pendingJobs = 0
        self.completedJobs = 0

        """
        :param buildStatus
               idle - No build running 
               started - new build started 
               running - build jobs running and awaiting completion
               SUCCESS - all jobs completed SUCCESSfully 
               failed - one or more jobs failed to complete succesfully 
               aborted - build jobs aborted or ended prematurely
        """

    def getName(self):
        return self.name

    def getDashboardColor(self):
        return self.dashboardColor

    def getJenkinsType(self):
        return self.jenkinsType

    def getJenkinsParentUrl(self):
        return self.jenkinsParentUrl

    def getJenkinsBuildUrl(self):
        return self.jenkinsBuildUrls

    def getGithubType(self):
        return self.githubType

    def getGithubUrl(self):
        return self.githubUrl

    def getMethod(self):
        return self.method

    def getState(self):
        return self.state

    def getBuildStatus(self):
        return self.buildStatus

    def getCurrBuildNum(self):
        return self.currBuildNum

    def getPrevBuildNum(self):
        return self.prevBuildNum

    def getTimeout(self):
        return self.timeout

    def getTimestamp(self):
        return self.timestamp

    def getPendingQueue(self):
        return self.job_queue

    def getLastSuccessfulBuild(self):
        return self.lastSuccessfulBuild

    def getHtmlDashboard(self):
        return self.htmlDashboard

    def getHtmlBuildHistory(self):
        return self.htmlBuildHistory

    def setBuildStatus(self, status):
        self.buildStatus = status

    def setHtmlDashboard(self, htmlFile):
        self.htmlDashboard = htmlFile

    def setHtmlBuildHistory(self, htmlFile):
        self.htmlBuildHistory = htmlFile

    def setLastSuccessfulBuild(self, bldNum):
        self.lastSuccessfulBuild = bldNum

    def update_runningTime(self):
        self.runningTime = datetime.now()
        time = self.runningTime.strftime('%m/%d/%Y %H:%M:%S') 
        logger.debug("Time {0}".format(time))

    def start(self, nextBuild=None):
        self.update_runningTime()
        if nextBuild is None:
            if not self.job_queue:
                self.state = "ready"
                logger.debug("Starting up: {0}".format(self.state))
            else:
                logger.warning("Already started...number of pending jobs: {0}".format(len(self.job_queue)))
        else:
            if self.state == "ready" or self.state == "running":
                self.state = "running" 
                self.buildStatus = "pending" 
                self.prevBuildNum = self.currBuildNum
                self.currBuildNum = nextBuild.getBuildNum()
                self.bldDuration = nextBuild.getDuration()  # Starting offset in Jenkins
                self.nCommits = len(nextBuild.getChangeSet())
                self.pendingJobs = nextBuild.getNumJobsPending()
                self.timestamp = nextBuild.getTimestamp()
                logger.debug("Build Num: {0}  state: {1}  buildStatus: {2}".format(self.currBuildNum, self.state, self.buildStatus))
            else:
                logger.debug("Not Ready...state: {0}".format(self.state))

        return (self.state, self.buildStatus)

    def update_build_status(self, currBuild):
        # Check for issues such as hang
        # Determine the cause and force a stop with "incomplete" status
        logger.debug("pendingJobs: {0}  completedJobs: {1}".format(self.pendingJobs, self.completedJobs))

        self.update_runningTime()
        jobList = currBuild.getBuildJobs()

        if self.pendingJobs != self.completedJobs:
            # Sanity check - problem if we ever enter here so force build to exit
            self.buildStatus = "failed"
            for job in jobList:
                if job.getStatus() == "pending":
                    logger.error("Fatal error detected on job: {0}".format(job.getJenkinsUrl()))
                    self.buildStatus = "incomplete"
                    break
        else:
            logger.debug("Builds in queue: {0}".format(len(self.job_queue)))
            # Update overall buildStatus based on all build jobs
            buildStatus = ""
            for job in jobList:
                status = job.getStatus()
                if not status or status == "" or status == "ABORT" or status == "TIMEOUT":
                    buildStatus = "incomplete" 
                else:
                    if status == "SUCCESS":
                        buildStatus = "success" 
                    elif status == "UNSTABLE":
                        buildStatus = "unstable" 
                    else:
                        buildStatus = "failed" 

                if self.buildStatus == "pending" or self.buildStatus == "success":
                    self.buildStatus = buildStatus 
                elif self.buildStatus != "incomplete" and buildStatus != "success":
                    self.buildStatus = buildStatus 

        logger.debug("Build status: {0}".format(self.buildStatus))
        return self.buildStatus

    def build_is_new(self, bldNum):
        if bldNum <= self.currBuildNum:
            return False
        else:
            for build in self.job_queue:
                if build.getBuildNum == bldNum:
                    return False
        return True

    def watching(self, job):
        if job in self.watch_queue:
            return True
        else:
            return False

    def add_build(self, bld):
        self.update_runningTime()
        if self.job_queue:
            if bld.getBuildNum() > self.job_queue[0].getBuildNum():
                self.job_queue.append(bld)
            else:
                self.job_queue.insert(0, bld)
        else:
            self.job_queue.append(bld)
        logger.debug("Queue length {0}".format(len(self.job_queue)))

    def del_build(self, bld):
        bld_pending = 0
        if i in self.job_queue: 
            if bld.getBuildNum == self.currBuildNum:
                if self.buildStatus == "pending":
                    bld_pending = 1
        if bld_pending == 0:
            self.job_queue.remove(bld)

        return bld_pending

    def get_current_build(self):
        build = None
        for build in self.job_queue:
            if self.currBuildNum == build.getBuildNum:
                return build
        return None 

    def get_next_build(self):
        build = None
        for build in self.job_queue:
            if build.getBuildNum() == self.currBuildNum:
                continue
            else:
                break
        return build

    def build_job_start(self, job, result):
        self.update_runningTime()
        self.pendingJobs += 1
        job.setStatus(result)
        self.watch_queue.append(job)

    def build_job_end(self, job, result):
        self.update_runningTime()
        self.completedJobs += 1

        # Need to update build duration from build start up to this job
        job.setStatus(result)
        self.watch_queue.remove(job)

    def finish(self, build):
        self.update_runningTime()

        # Current build ended. Update results and calculate duration
        # from build start to last job complete
 
        if self.buildStatus == "success":
            self.lastSuccessfulBuild = self.currBuildNum

        # Only remove build from queue at this point 
        if build in self.job_queue:
            self.job_queue.remove(build)
        else: 
            logger.debug("Build queue out of sync...{0} not found".format(build.getBuildNum()))

        self.pendingJobs = 0
        self.completedJobs = 0

        # Keep dashboard_monitor thread running if still have builds in queue
        if self.job_queue:
            self.state = "running" 
        else:
            self.state = "ready" 

        logger.debug("Build status: {0} state: {1}".format(self.buildStatus, self.state))

    def close(self):
        # Check for pending jobs
        if self.job_queue:
            logger.warning("Terminating monitor jobs...not implemented")

    def __repr__(self):
        return ('Dashboard {0}'.format(self, self.name))
