#!/usr/bin/python
# coding: UTF-8 

import os
import sys
import io
import re
import stat
import signal
import json
import traceback
import requests
import threading
import subprocess
import collections
import logging
import time
from datetime import datetime
from subprocess import check_call
from optparse import OptionParser
from pprint import pprint

from git import Repo
import xml.etree.ElementTree as ET

import urllib2
import httplib
import socket
from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler
from SocketServer import ThreadingMixIn
from bs4 import BeautifulSoup

from util.dashboard import Dashboard
from util.buildHistory import buildHistory
from util.buildDBI import *

__version__ = "1.1.0"

#_JIRA_PATTERN = r'([A-Z]{2,5}-[0-9]{1,6})'
_JIRA_PATTERN = r'(\b[A-Z]+-\d+\b)'

_GITHUB_TOKEN = ''
with open(os.path.join(os.path.expanduser('~'), '.githubtoken')) as F:
    _GITHUB_TOKEN = F.read().strip()

#BUILDHISTORY_BUCKET = 'couchbase://buildboard-db:8091/build-history'

class buildThreads(object):
    parent=[]
    child=[]

# Dashboards (live builds)
threadPools = []
dashboardPool = []

logger = logging.getLogger()
log_file = "buildboard.log"

issueLabels = ["CB", "MB", "SDK"]
projPrivate = ["voltron", "cbbuild"]

def enable_logging(log_level):
    try:
        if os.path.isfile(log_file):
            os.remove(log_file)
    except OSError, e:
        print ("ERROR: {0} - {1}".format(e.filename, e.strerror))
  
    if log_level.upper() == "DEBUG": 
        level = logging.DEBUG
    elif log_level.upper() == "INFO": 
        level = logging.INFO
    elif log_level.upper() == "WARNING": 
        level = logging.WARNING
    else:
        level = logging.ERROR
 
    logger.setLevel(level)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(funcName)20s() - %(message)s')

    # Log to file
    fh = logging.FileHandler(log_file)
    fh.setLevel(level)
    fh.setFormatter(formatter)
    logger.addHandler(fh)

def findThread(thread):
    for t in threadPools:
        if thread == t.parent:
            return t
        for child in t.child:
            if thread == child:
                return t
    return None

def findThreadByName(name):
    for t in threadPools:
        pt = t.parent
        if name == pt.getName():
            return pt
        for child in t.child:
            if name == child.getName():
                return child
    return None


#################### HTML Templates #####################
#
def html_update_dashboard_table (name):
    filename = name + '.html'

    logger.debug("To be implemented")
    htmlFile = os.path.dirname(os.path.abspath(__file__))+"/html/{0}".format(filename)

    return True


####################### Jenkins Utility ########################
#
# Uses Jenkins REST API
#
def jenkins_get_contents(url, params={"depth" : 0}):
    contents = None
    res = None

    for x in range(5):
        try:
            res = requests.get("%s/%s" % (url, "api/json"), params = params, timeout=10)
            if res:
                contents = res.json()
                break
        except:
            logger.error("url unreachable: %s" % url)
            time.sleep(5)

    return contents


def jenkins_get_envVars(url):
    contents = None
    envVars_url = url + 'injectedEnvVars'

    contents = jenkins_get_contents(envVars_url)

    return contents


def jenkins_job_queue_not_empty(url):
    contents = None

    # Access issue so assume queue not empty
    contents = jenkins_get_contents(url)
    if contents is None:
        return True

#    if 'queueItem' in contents and contents['queueItem']:
    if 'inQueue' in contents and contents['inQueue']:
        return True

    return False


def jenkins_get_changeSet(dashbrd, url):
    items = []
    commits = []
    changeSet = {}

    # Build summary detail
    jenkinsUrl = "{0}/changes#detail0".format(url)

    logger.debug("{0}".format(jenkinsUrl))

    try:
        rsp = urllib2.urlopen(jenkinsUrl, timeout=10)
        html = rsp.read()
        summary = BeautifulSoup(html, "html.parser") 
        rsp.close()
    except (httplib.BadStatusLine, urllib2.HTTPError, urllib2.URLError) as e:
        logger.error("Error {0} accessing Jenkins summary detail at {1}".format(e, jenkinsUrl))
        return None
    except socket.timeout: 
        logger.warning("Jenkins request timeout {0}".format(jenkinsUrl))
        return None
 
    changes = summary.findAll("div", {"class": "changeset-message"})

    for change in changes:
        change = change.text.strip()
        change = change.split(":")
        for line in change:
            line = line.replace("\n", "")
            line = line.replace("\t", "")
            line = line.replace(" ", "")
            items.append(line)

    write_data = ""
    for i in items:
        result = {}
        # Jenkins seem to have a bug
        if write_data == "repo":
            if 'Revision' in i:
                result["repo"] = i.replace("Revision", "")
                write_data = "commitId"
            else:
                result['repo'] = i
                write_data = ""
            # Need to handle private Project 
            if 'manifest' in result['repo']: 
                result['repo'] = u'manifest'
            else:
                proj = result['repo'].split("/")
                result['repo'] = proj[-1]
            logger.debug("{0} Repo: {1}".format(dashbrd.getName(), result['repo']))
            continue
        if write_data == "commitId":
            if 'Author' in i:
                result['commitId'] = i.replace("Author", "")
                write_data = "author"
            else:
                result['commitId'] = i
                write_data = "Null"
            logger.debug("{0} commitID: {1}".format(dashbrd.getName(), result['commitId']))
            commits.append(result)
            continue

        if 'Project' in i:
            write_data = "repo"
        elif 'Revision' in i:
            write_data = "commitId"

    # Need to change to get history from GitHub.  Jenkins has has too many data formatting issues (To-Do)
    logger.debug(commits)
    changeSet['commits'] = commits

    return changeSet


def jenkins_get_test_results(url, sanity=False):
    testResults = []

    jContents = jenkins_get_contents(url)
    if jContents is None:
        return None

    if 'suites' not in jContents:
        return None

    for s in jContents['suites']:
        suite = {}
        suite['suite'] = s['name']
        suite['duration'] = s['duration']
        cases = []
        for c in s['cases']:
            case = {}
            if sanity:
                n, p = c['name'].split(',', 1)
                case['name'] = n
                case['params'] = p
            else:
                case['name'] = c['name']
                case['params'] = ''
            case['duration'] = c['duration']
            case['status'] = c['status']
            case['failedSince'] = c['failedSince']
            cases.append(case)
        suite['cases'] = cases
        testResults.append(suite)

    return testResults


def jenkins_get_unitTest(dashbrd, url):
    testHistory = {}

    # Job entry point
    jContents = jenkins_get_contents(url)
    if jContents is None:
        return None
  
    jEnvVars = jenkins_get_envVars(url)
    if jEnvVars is None:
        return None

    envVars = jEnvVars['envMap']

    results = {}
    results['docId'] = "" 
    results['result'] = ""

    for a in jContents['actions']:
        if a.has_key('totalCount'):
            testHistory['testCount'] = a['totalCount']
            testHistory['failedTests'] = a['failCount']
            testHistory['skipTests'] = a['skipCount']
            testHistory['testReportUrl'] = (envVars['BUILD_URL'] + '/' + a['urlName']).format(envVars['BLD_NUM'])
            break

    if 'testReportUrl' not in  testHistory:
        results['result'] = 'unknown'
        logger.debug("Test report url error")
        return results

    if url.find('windows') != -1:
        arch = 'amd64'
        if envVars.has_key('ARCHITECTURE'):
            arch = envVars['ARCHITECTURE']
        testHistory['distro'] = 'win-' + arch
    else:
        if envVars.has_key('DISTRO'):
            testHistory['distro'] = envVars['DISTRO']
        elif envVars.has_key('PLATFORM'):
            testHistory['distro'] = envVars['PLATFORM']

    if 'EDITION' in envVars:
        testHistory['edition'] = envVars['EDITION']
    else:
        testHistory['edition'] = "enterprise" 

    testHistory['branch'] = dashbrd.getBranch()
    testHistory['build_num'] = int(envVars['BLD_NUM'])
    testHistory['version'] = envVars['VERSION']
    testHistory['jobType'] = "unit_test" 
    testHistory['url'] = url

    # Work around naming inconsistency.  We seriously need a standard in our build process.
    if 'ubuntu12' in testHistory['distro']:
        testHistory['distro'] = 'ubuntu12.04'
    elif 'ubuntu14' in testHistory['distro']:
        testHistory['distro'] = 'ubuntu14.04'

    jobId = testHistory['version']+'-'+str(testHistory['build_num'])+'-'+testHistory['distro']+'-'+testHistory['edition']
    bldJob = db_doc_exists(jobId)
    if not bldJob:
        # Return empty test result to allow test job to stay in the queue
        # This handles initial startup where the test info appears before the build job in DB
        results['result'] = 'pending'
        return results

    if jContents['result']: 
        if jContents['result'] == 'SUCCESS':
            testHistory['result'] = 'PASSED'
        else:
            testHistory['result'] = 'FAILED'
    else:
        testHistory['result'] = "" 

    docId = testHistory['version']+'-'+str(testHistory['build_num'])+'-'+testHistory['distro']+'-'+testHistory['jobType']

    # If unitTest already in DB, check result for progress 
    testDoc = db_doc_exists(docId)
    if testDoc:
        if testDoc.value['result']:
            # Result is in so all done
            testHistory['result'] = testDoc.value['result']
        else:
            testHistory['testReport'] = jenkins_get_test_results(testHistory['testReportUrl'])
            testHistory['duration'] = jContents['duration']
            db_update_test_result(testHistory)
    else:
        testHistory['timestamp'] = jContents['timestamp']
        testHistory['duration'] = jContents['duration']
        testHistory['slave'] = jContents['builtOn']
        testHistory['testReport'] = jenkins_get_test_results(testHistory['testReportUrl'])
        docId = db_insert_test_history(testHistory)
        db_build_attach_unitTest(docId, testHistory['edition'])

    results['url'] = testHistory['url']
    results['version'] = testHistory['version']
    results['build_num'] = testHistory['build_num']
    results['distro'] = testHistory['distro']
    results['jobType'] = testHistory['jobType']
    results['result'] = testHistory['result']
    return results


def jenkins_get_sanity(dashbrd, url):
    testHistory = {}

    results = {}
    results['docId'] = "" 
    results['result'] = ""

    # Job entry point
    jContents = jenkins_get_contents(url)
    if jContents is None:
        return None
  
    jEnvVars = jenkins_get_envVars(url)
    if jEnvVars is None:
        return None

    envVars = jEnvVars['envMap']

    curBldNum = e['envMap']['CURRENT_BUILD_NUMBER']
    if "EDITION" in envVars:
        edition = envVars['EDITION']
    else:
        edition = 'enterprise'

    buildId = e['envMap']['VERSION'] + '-' + curBldNum

    buildDoc = db_doc_exists(buildId)
    if not buildDoc:
        self.logger.warning('Could not find build {} in DB'.format(buildId))
        return results 

    buildHist = buildDoc.value
    if buildHist.has_key('sanity_result'):
        sres = buildHist['sanity_result']
        if sres != 'INCOMPLETE':
            self.logger.debug('_poll_build_sanity: reached the run that has already been saved')
            return 'stop'
        if sres == 'INCOMPLETE' and j['building']:
            self.logger.debug('_poll_build_sanity: this is a run that is still running {}'.format(burl))
            return 'continue'
    elif j['building']:
        bld_doc['sanity_result'] = 'INCOMPLETE'
        bld_doc['sanity_url'] = burl
        self.logger.debug('update db - incomplete build_sanity for {}'.format(version))
        self.logger.debug(bld_doc)
        self.bldDB.insert_build_history(bld_doc, True)
        return 'continue'



    results = {}
    results['docId'] = "" 
    results['result'] = ""

    for a in jContents['actions']:
        if a.has_key('totalCount'):
            testHistory['testCount'] = a['totalCount']
            testHistory['failedTests'] = a['failCount']
            testHistory['skipTests'] = a['skipCount']
            testHistory['testReportUrl'] = (envVars['BUILD_URL'] + '/' + a['urlName']).format(envVars['BLD_NUM'])
            break

    if 'testReportUrl' not in  testHistory:
        results['result'] = 'unknown'
        logger.debug("Test report url error")
        return results

    if url.find('windows') != -1:
        arch = 'amd64'
        if envVars.has_key('ARCHITECTURE'):
            arch = envVars['ARCHITECTURE']
        testHistory['distro'] = 'win-' + arch
    else:
        if envVars.has_key('DISTRO'):
            testHistory['distro'] = envVars['DISTRO']
        elif envVars.has_key('PLATFORM'):
            testHistory['distro'] = envVars['PLATFORM']

    if "EDITION" in envVars:
        testHistory['edition'] = envVars['EDITION']
    else:
        testHistory['edition'] = "enterprise" 

    testHistory['branch'] = dashbrd.getBranch()
    testHistory['build_num'] = int(envVars['BLD_NUM'])
    testHistory['version'] = envVars['VERSION']
    testHistory['jobType'] = "unit_test" 
    testHistory['url'] = url

    jobId = testHistory['version']+'-'+str(testHistory['build_num'])+'-'+testHistory['distro']+'-'+testHistory['edition']
    bldJob = db_doc_exists(jobId)
    if not bldJob:
        # Return empty test result to allow test job to stay in the queue
        # This handles initial startup where the test info appears before the build job in DB
        results['result'] = 'pending'
        return results


# Test results need to be uniform or standardized; Currently it is not.
def jenkins_get_builtin_unitTest(dashbrd, url):
    testHistory = {}

    # Job entry point
    jContents = jenkins_get_contents(url)
    if jContents is None:
        return None
  
    jEnvVars = jenkins_get_envVars(url)
    if jEnvVars is None:
        return None

    envVars = jEnvVars['envMap']

    results = {}
    results['docId'] = "" 
    results['result'] = ""

    for a in jContents['actions']:
        if a.has_key('totalCount'):
            testHistory['testCount'] = a['totalCount']
            testHistory['failedTests'] = a['failCount']
            testHistory['skipTests'] = a['skipCount']
            testHistory['testReportUrl'] = (envVars['BUILD_URL'] + '/' + a['urlName']).format(testHistory['build_num'])
            break

    if 'testReportUrl' not in  testHistory:
        logger.debug("Missing test report url")
        return results

    if url.find('windows') != -1:
        arch = 'amd64'
        if envVars.has_key('ARCHITECTURE'):
            arch = envVars['ARCHITECTURE']
        testHistory['distro'] = 'win-' + arch
    else:
        if envVars.has_key('DISTRO'):
            testHistory['distro'] = envVars['DISTRO']
        elif envVars.has_key('PLATFORM'):
            testHistory['distro'] = envVars['PLATFORM']

    testHistory['edition'] = envVars['EDITION']
    testHistory['branch'] = dashbrd.getBranch()
    testHistory['build_num'] = int(envVars['BLD_NUM'])
    testHistory['version'] = envVars['VERSION']
    testHistory['jobType'] = "unit_test" 
    testHistory['result'] = jContents['result']
    testHistory['url'] = url

    docId = testHistory['version']+'-'+str(testHistory['build_num'])+'-'+testHistory['distro']+'-'+testHistory['edition']+'-'+testHistory['jobType']

    # If unitTest already in DB, check result for progress 
    testDoc = db_doc_exists(docId)
    if testDoc:
        if testDoc.value['result']:
            # Result is in so all done
            testHistory['result'] = testDoc.value['result']
        else:
            testHistory['testReport'] = jenkins_get_test_results(testHistory['testReportUrl'])
            testHistory['duration'] = jContents['duration']
            docId = db_update_test_result(testHistory)
    else:
        testHistory['testReport'] = jenkins_get_test_results(testHistory['testReportUrl'])
        testHistory['timestamp'] = jContents['timestamp']
        testHistory['duration'] = jContents['duration']
        testHistory['slave'] = jContents['builtOn']
        testHistory['jobType'] = 'unit_test'
        docId = db_insert_test_history(testHistory)

    results['docId'] = docId 
    results['version'] = testHistory['version']
    results['build_num'] = testHistory['build_num']
    results['distro'] = testHistory['distro']
    results['jobType'] = testHistory['jobType']
    results['result'] = testHistory['result']
    return results


def jenkins_get_build_job(dashbrd, url):
    jobHistory = {}
    stats = {}

    # Job entry point
    jContents = jenkins_get_contents(url)
    if jContents is None:
        return None

    jEnvVars = jenkins_get_envVars(url)
    if jEnvVars is None:
        return None

    envVars = jEnvVars['envMap']

    if url.find('windows') != -1:
        arch = 'amd64'
        if envVars.has_key('ARCHITECTURE'):
            arch = envVars['ARCHITECTURE']
        jobHistory['distro'] = 'win-' + arch
    else:
        if envVars.has_key('DISTRO'):
            jobHistory['distro'] = envVars['DISTRO']
        elif envVars.has_key('PLATFORM'):
            jobHistory['distro'] = envVars['PLATFORM']

    jobHistory['edition'] = envVars['EDITION']
    jobHistory['branch'] = dashbrd.getBranch()
    jobHistory['build_num'] = int(envVars['BLD_NUM'])
    jobHistory['version'] = envVars['VERSION']

    docId = jobHistory['version']+'-'+str(jobHistory['build_num'])+'-'+jobHistory['distro']+'-'+jobHistory['edition'] 

    # If UNIT_TEST is True, the state can transit to passed or failed
    if envVars.has_key('UNIT_TEST') and envVars['UNIT_TEST']:
        stats['unitTest'] = True 
    else:
        stats['unitTest'] = False 

    # First verify if build is already in DB 
    doc = db_doc_exists(docId)
    if not doc:
        jobHistory['unitTest'] = "" 
        jobHistory['sanity'] = "" 
        jobHistory['timestamp'] = jContents['timestamp']
        jobHistory['slave'] = jContents['builtOn']
        jobHistory['jobType'] = 'distro_level_build'
        jobHistory['jenkinsUrl'] = envVars['BUILD_URL']

        # Update DB Job History
        docId = db_insert_job_history(jobHistory)
        if not docId:
            logger.debug("{0}...Failed to insert {1} into DB".format(jobHistory['branch'], jobHistory['build_num']))
            return stats

    stats['version'] = jobHistory['version']
    stats['build_num'] = jobHistory['build_num']
    stats['distro'] = jobHistory['distro']
    stats['edition'] = jobHistory['edition']
    stats['result'] = jContents['result']
    stats['duration'] = int(jContents['duration'])

    logger.debug("{0}-{1}...{2}".format(stats['version'], stats['build_num'], stats['result']))

    return stats 


# Traverse downstream and return the list of jobs discovered
def jenkins_walk_downstream_jobs(parentUrl, parentBldNum):
    jobList = []

    logger.debug("{0}".format(parentBldNum))

    url = parentUrl + "{0}/".format(parentBldNum)
    jContents = jenkins_get_contents(url)
    if jContents is None:
        return jobList 

    for dp in jContents['downstreamProjects']:
        if dp["url"]:
            downstream_builds = jenkins_get_contents(dp['url'])
            if downstream_builds is None:
                continue

            # Find downstream jobs with corresponding parentBldNum
            for build in downstream_builds['builds']:
                jobData = jenkins_get_contents(build['url'])
                if jobData is None:
                    continue

                upstreamBldNum = 0
                actions = jobData['actions']
                for action in jobData['actions']:
                    if "causes" in action:
                        upstreamBldNum = action['causes'][0]['upstreamBuild']
                        logger.debug(upstreamBldNum)
                        break

                if parentBldNum == upstreamBldNum:
                    jobList.append(build['url'])
                    break

            # Walk downstream
            if downstream_builds['downstreamProjects']:
                nextJobs = jenkins_walk_downstream_jobs(dp['url'], jobData['number'])
                jobList.append(nextJobs)

    return jobList


def jenkins_get_matching_jobs(url, version, bldNum):
    #
    # Find and return list of jobs that match the bldNum
    #
    jobUrls = []
    multiJobs = []

    logger.debug("Input bldNum {0}".format(bldNum))

    jContents = jenkins_get_contents(url)
    if jContents is None: 
        return None

    for build in jContents['builds']:
        logger.debug("Downstream {0}".format(build['url']))
        jenkinsBuildNum = 0
        # Find downstream jobs with corresponding bldNum
        buildJob = jenkins_get_contents(build['url'])

        if buildJob is not None:
            jEnvVars = jenkins_get_envVars(build['url'])
            if jEnvVars is None:
                break

            if 'VERSION' not in jEnvVars['envMap'] or version != jEnvVars['envMap']['VERSION']:
                continue

            jenkinsBuildNum = int(jEnvVars['envMap']['BLD_NUM'])

            if jenkinsBuildNum == bldNum:
                logger.debug("parentBuild {0} matches Job BLD_NUM {1}".format(bldNum, jenkinsBuildNum))
                jobUrls.append(build['url'])
                continue
            elif jenkinsBuildNum < (bldNum - 3):
                # Avoid searching through the entire Jenkins job history every time
                break

    logger.debug("Build {0} has {1} matching jobs".format(bldNum, len(jobUrls)))

    return jobUrls


def jenkins_get_parent_builds(dashbrd, parentBldNum, url):
    name = dashbrd.getName()
    jContents = {} 
    hist = {}

    logger.debug("{0} parentBldNum: {1}".format(name, parentBldNum))

    # Parent job entry point
    jContents = jenkins_get_contents(url)
    if jContents is None:
        return None
  
    jEnvVars = jenkins_get_envVars(url)
    if jEnvVars is None:
        return None

    envVars = jEnvVars['envMap']

    hist['build_num'] = int(envVars['BLD_NUM'])
    hist['timestamp'] = jContents['timestamp']

    version = envVars ['VERSION']
    if envVars.has_key('PRODUCT_BRANCH'):
        branch = envVars['PRODUCT_BRANCH']     
    elif envVars.has_key('BRANCH'):
        branch = envVars['BRANCH']     
 
    hist['branch'] = dashbrd.getBranch() 
    hist['version'] = dashbrd.getVersion() 
    docId = hist['version'] + '-' + envVars['BLD_NUM']

    # Only proceed if found matching branch and version
    if hist['branch'] != branch or hist['version'] != version:
        return None

    # If build already in DB, check build result for progress 
    buildDoc = db_doc_exists(docId)
    if buildDoc:
        params = buildDoc.value
        if "result" in params and params['result']:
            # Nothing to do if build result has final build status
            return None
        else:
            logger.debug("{0} parentBuildNum: {1}  DB release {2}".format(name, parentBldNum, params['release']))
            newBuild = buildHistory(params)
            logger.debug("{0} parentBuildNum: {1}  dashboard buildHistory {2}".format(name, parentBldNum, newBuild))
            return newBuild

    hist['release'] = envVars['RELEASE']
    hist['manifest'] = dashbrd.getManifest()
    hist['binary'] = dashbrd.getBinPath()

    hist['manifest_sha'] = ""
    if envVars.has_key('MANIFEST_SHA'):
        hist['manifest_sha'] = envVars['MANIFEST_SHA']
    else:
        hist['manifest_sha'] = github_get_manifest_sha(dashbrd,
                                                       hist['manifest'],
                                                       hist['timestamp'],
                                                       hist['version']+'-'+str(hist['build_num']))

    hist['passed'] = []
    hist['failed'] = []
    hist['sanity'] = []
    hist['unitTest'] = []
    hist['jobType'] = "parent_build"

    # Get commit change info
    changeSet = {}
    if dashbrd.getChangeRequestFrom() == "jenkins":
        changeSet = jenkins_get_changeSet(dashbrd, url) 
    else:
        changeSet = github_get_changeSet(dashbrd, parentBldNum,
                                                  hist['manifest'],
                                                  hist['manifest_sha'])
    logger.debug("{0} parentBuildNum: {1}  Getting commit info {2}".format(name, parentBldNum, changeSet))

    hist['jenkinsUrl'] = url
    hist['result'] = ""
    hist['duration'] = int(jContents['duration'])
    hist['released'] = "False"

    hist["commits"] = [] 
    if changeSet['commits']:
        hist["commits"] = changeSet['commits'] 

    hist["repo_deleted"] = []
    if changeSet['repo_deleted']:
        hist['repo_deleted'] = changeSet['repo_deleted'] 

    # Create new instance of build history and write to DB
    logger.debug("{0} parentBuildNum: {1}  Inserting build history to DB".format(name, parentBldNum))
    newBuild = buildHistory(hist)
    if newBuild:
        db_insert_build_history(hist)
    else:
        logger.debug("{0} Build {1} Failed to create buildHistory for monitoring".format(name, parentBldNum))
        newBuild = None
    logger.debug("{0} parentBuildNum: {1}  dashboard buildHistory {2}".format(name, parentBldNum, newBuild))

    return newBuild


def jenkins_get_new_jobs(url, version, buildNum, gitType, manifest):
    #
    # Find and return list of jobs newer than the specified bldNum
    # List returned in ascending order
    # buildNum is our BLD_NUM, not the jenkins (job) build number
    #
    bldList = []

    logger.debug("{0} {1}".format(url, buildNum))

    jContents = jenkins_get_contents(url)
    if not jContents:
        return bldList
 
    if not jContents.has_key('builds'):
        logger.warning("Build information not available from Jenkins")
        return bldList

    # Scan for new and active builds
    for build in jContents['builds']: 
        job = {}
        if build.has_key('number'):
            jenkinsJobNum = build['number']
        else:
            break

        if build.has_key('url'):
            job['url'] = build['url'] 
        else:
            break

        jEnvVars = jenkins_get_envVars(build['url'])
        if jEnvVars is None:
            break

        envVars = jEnvVars['envMap'] 
        if gitType == "repo":
            if manifest != envVars.get('MANIFEST', ''):
                continue 

        if envVars.has_key('VERSION') and version != envVars['VERSION']:
            continue

        if envVars.has_key('BLD_NUM'):
            bldNum = int(envVars['BLD_NUM'])
        else:
            bldNum = int(jenkinsJobNum)

        job['bldNum'] = bldNum 
        if bldNum >= buildNum:
            bldList.append(job)

        if bldNum < buildNum:
            break

    bldList.reverse()
    return bldList


def jenkins_scan_unitTest(dashbrd):
    #
    # Scan for all new sanity jobs up to the last completed job
    #
    name = dashbrd.getName()
    version = dashbrd.getVersion()
    unitTestUrls = dashbrd.getUnitTestUrls()
    gitType = ""
    manifest = "" 
    job_list = []
    unitTest = {}

    logger.debug("{0}: {1}".format(name, unitTestUrls))

    # Service pending jobs
    jobQueue = dashbrd.getPendingUnitTest()
    for job in jobQueue:
        unitTest = jenkins_get_unitTest(dashbrd, job['url'])
        if unitTest['result']:
            dashbrd.update_unitTest(unitTest)
            db_update_test_result(unitTest)
            logger.debug("{0} unit tests {1} completed".format(name, unitTest['url']))

    # Scan for new jobs
    curUnitTestBldNum = dashbrd.getCurUnitTestBldNum()
    logger.debug("{0} Current unit tests {1}".format(name, curUnitTestBldNum))

    job_list = jenkins_get_new_jobs(unitTestUrls, version, curUnitTestBldNum, gitType, manifest)
    logger.debug("{0} Found new unit tests {1}".format(name, job_list))

    # Create and record new unit tests into database
    for job in job_list: 
        logger.debug("{0} parsing unit tests {1}".format(name, job['url']))
        unitTest = jenkins_get_unitTest(dashbrd, job['url'])
        if not unitTest['result']:
            qlen = dashbrd.add_unitTest(unitTest)
            logger.debug("{0} Found new unit tests #{1} total in queue {2}".format(name, unitTest['build_num'], qlen))
        elif unitTest['result'] != 'pending' and unitTest['result'] != 'unknown':
            dashbrd.advance_curUnitTestBldNum(unitTest['build_num'])
            logger.debug("{0} new unit tests {1} result already in DB".format(name, unitTest['build_num']))


def jenkins_scan_builds(dashbrd):
    #
    # Scan for new builds from parent build job up to the last build
    #
    name = dashbrd.getName()
    version = dashbrd.getVersion()
    parentUrl = dashbrd.getParentUrl()
    gitType = dashbrd.getGitType()
    manifest = dashbrd.getManifest()
    curBldNum = dashbrd.getCurBuildNum()
    qlen = 0
    bld_list = []

    logger.debug("{0}: {1}".format(name, parentUrl))

    dashbrd.scanning()

    # Scan for new and active jobs
    bld_list = jenkins_get_new_jobs(parentUrl, version, curBldNum, gitType, manifest)

    # Create and enter each build into our database
    for build in bld_list: 
        newBuild = jenkins_get_parent_builds(dashbrd, build['bldNum'], build['url'])
        if newBuild:
            qlen = dashbrd.add_build(newBuild)
            logger.debug("{0} Found new build #{1} total {2} builds".format(name, newBuild.getBuildNum(), qlen))
        else:
            logger.warning("{0} Build #{1} completed and entered in DB".format(name, build['bldNum']))
        
    logger.debug("{0} Scanned {1} incomplete builds".format(name, qlen))

    dashbrd.idle()

    return qlen


#################### GITHUB Utility #####################
#
# Need Python Git module
#
def github_read(url, params={"depth" : 0}):
    data = None
    res = None

    token={'Authorization': 'token {0}'.format(_GITHUB_TOKEN)}

    for x in range(3):
        try:
            res = requests.get(url, headers=token, params=params, timeout=10)
            if res:
                data = res.json()
                break
        except:
            logger.error("url unreachable: %s" % url)
            time.sleep(5)

    return data


def github_scan_builds(dashbrd):
    nBuilds = 0
    name = dashbrd.getName()

    dashbrd.scanning()
    logger.debug("{0} Discovered {1} builds".format(name, nBuilds))
    dashbrd.idle()

    return nBuilds


def github_get_fixed_issues(msg, issueType):
    issues = []

    title = msg.split('\n', 1)[0]
    if issueType == "jira":
        matches = re.findall(_JIRA_PATTERN, title)

    if matches:
        for tix in matches:
            issues.append(tix)
    return issues


def github_get_changeSet(dashbrd, bldNum, manifest, manifest_sha):
    changeSet = {}

    _GITREPO = dashbrd.getPyGitRepo()

    version = dashbrd.getVersion()
    prv_bnum = bldNum - 1

    logger.debug('Build: #{0}, manifest {1}, manifest_sha {2}'.format(bldNum, manifest, manifest_sha))

    docId = dashbrd.getVersion() + '-' + str(prv_bnum)
    doc = db_doc_exists(docId)
    if doc: 
        prv_sha = doc.value['manifest_sha']
        if not prv_sha: 
            prv_sha = manifest_sha+'~1'
    else:
        prv_sha = manifest_sha+'~1'

    _GITREPO.git.checkout(dashbrd.getBranch())
    o = _GITREPO.remotes.origin
    o.pull()
    m1 = _GITREPO.git.show("%s:%s" % (manifest_sha, manifest))
    m2 = _GITREPO.git.show("%s:%s" % (prv_sha, manifest))
    mxml1 = ET.fromstring(m1)
    mxml2 = ET.fromstring(m2)
    p1list = {}
    p2list = {}
    proj1 = mxml1.findall('project')
    proj2 = mxml2.findall('project')
    for p in proj1:
        n = p.get('name')
        v = p.get('revision')
        r = p.get('remote') or 'couchbase'
        p1list[n] = (v,r)
    for p in proj2:
        n = p.get('name')
        v = p.get('revision')
        if v is None:
            v = p1list[n][0]
        r = p.get('remote') or 'couchbase'
        p2list[n] = (v,r)

    p1projs = p1list.keys()
    p2projs = p2list.keys()
    added = [x for x in p1projs if x not in p2projs]
    deleted = [x for x in p2projs if x not in p1projs]
    common = [x for x in p1projs if x not in added]

    changeSet = {}
    repo_changes = []
    repo_added = []
    repo_deleted = []

    REMOTES = dashbrd.getGithubRemotes()

    in_build = dashbrd.getVersion() + '-' + str(bldNum)

    for k in common:
        if p1list[k][0] == p2list[k][0]:
            continue
        giturl = REMOTES[p1list[k][1]] + k + '/compare/' + p2list[k][0] + '...' + p1list[k][0]
        j = github_read(giturl) 
        if not j:
            return ""

        commits = j['commits']
        for c in commits:
            commit = {}
            commit['in_build'] = [in_build]
            commit['repo'] = k
            commit['sha'] = c['sha']
            commit['committer'] = c['commit']['committer']
            commit['author'] = c['commit']['author']
            commit['url'] = c['html_url']
            commit['message'] = c['commit']['message']
            commit['type'] = 'commit'
            commit['fixes'] = github_get_fixed_issues(commit['message'], "jira")

            logger.debug("Insert commit {0}-{1} into DB".format(k, c['sha']))
            ret = db_insert_commit(commit)
            if ret:
                repo_changes.append(ret)

    for k in added:
        giturl = REMOTES[p1list[k][1]] + k + '/commits?sha=' + p1list[k][0]
        j = github_read(giturl) 
        if not j:
            return ""

        for c in j:
            commit = {}
            commit['in_build'] = [in_build]
            commit['repo'] = k
            commit['sha'] = c['sha']
            commit['committer'] = c['commit']['committer']
            commit['author'] = c['commit']['author']
            commit['url'] = c['html_url']
            commit['message'] = c['commit']['message']
            commit['type'] = 'commit'
            commit['fixes'] = github_get_fixed_issues(commit['message'], "jira")

            logger.debug("Insert commit {0}-{1} into db".format(k, c['sha']))
            ret = db_insert_commit(commit)
            if ret:
                repo_added.append(ret)

    for k in deleted:
        logger.debug("Repo {0} was removed in this commit".format(k))
        repo_deleted.append(k)

    changeSet['commits'] = repo_changes + repo_added
    changeSet['repo_deleted'] = repo_deleted

    return changeSet


def github_get_manifest_sha(dashbrd, man_file, build_time, version):
    gitProj = dashbrd.getBuildProject()

    logger.debug('github_get_manifest_sha: polling github for SHA: man_file {0} and version {1}'.format(man_file, version))

    btime = datetime.fromtimestamp(build_time/1000)
    until = btime.isoformat()
    logger.debug('{0}: {1} {2}'.format(dashbrd.getName(), btime, until))

    gitProjUrl = 'https://api.github.com/repos/couchbase/{0}'.format(gitProj)
#    gitApiParams = '/commits?until={0}&&path={1}'.format(until, man_file)
    gitApiParams = '/commits?until={0}'.format(until)
    giturl = gitProjUrl + gitApiParams

    j = github_read(giturl) 
    if not j:
        return ""

    for c in j:
        msg = c['commit']['message']
        if msg.find(version) != -1:
            logger.debug('{0}: github_get_manifest_sha: got SHA from github: {1}'.format(dashbrd.getName(), c['sha']))
            return c['sha']

    return ""


######################## Buildboard Services ##############################

def shutdown ():
    logger.info("Buildboard cleanup and saving data!")

    # Gracefully stop pending threads before removing 
    if threadPools:
        del threadPools[:]
        
    # Save all running data
    for i in range(len(dashboardPool)):
        dashbrd = dashboardPool.pop()
        dashbrd.close()


def dashboard_watch_job(dashbrd, buildJob):
    # Update Dashboard
    logger.debug("Watch a particular job out of band")


def dashboard_monitor(dashbrd):
    # 
    # Monitor build (per thread) 
    #   - process live running data
    #   - health of active builds
    #   - update build result in DB
    # 
    dashbrd.start_monitor()

    gitType = dashbrd.getGitType()
    parentUrl = dashbrd.getParentUrl()
    buildUrls = dashbrd.getBuildUrl()

    t = threading.currentThread()
    ct = findThread(t)
    tname = t.getName()
    dname = dashbrd.getName()
    logger.debug("{0} thread {1} {2} {3}".format(dname, tname, t, dashbrd.getState()))

    completedJobs = []
    curBuild = dashbrd.get_current_build()
    parentBldNum = dashbrd.getCurBuildNum()

    # Monitor all build jobs in queue
    while dashbrd.getState() == "monitoring":
        jobList = []
        if gitType == "repo":
            for url in buildUrls:
                jobUrls = []
                jobUrls = jenkins_get_matching_jobs(url, dashbrd.getVersion(), parentBldNum)
                jobList += [job for job in jobUrls if job not in completedJobs]
            for job_url in jobList:
                stats = jenkins_get_build_job(dashbrd, job_url)
                # Check for unit tests only after job has completed 
                if stats and stats['result']: 
                    docId = stats['version']+'-'+str(stats['build_num'])+'-'+stats['distro']+'-'+stats['edition'] 
                    testResults = jenkins_get_builtin_unitTest(dashbrd, job_url)
                    if testResults['result']:
                        db_update_test_result(testResults)
                        db_build_attach_unitTest(testResults['docId'], stats['edition'])
                    jobResult = dashbrd.update_build_job_result(curBuild, docId, stats['result'], stats['duration'], testResults)
                    db_update_build_job_result(docId, jobResult, stats['duration'], testResults['docId'])
                    completedJobs.append(job_url)
                    logger.debug("{0} Completed Jenkins job {1} result={2}".format(dname, len(completedJobs), stats['result']))
        elif gitType == "git":
            jobUrls = jenkins_walk_downstream_jobs(parentUrl, parentBldNum)
            jobList = [job for job in jobUrls if job['url'] not in completedJobs]
            for job in jobList:
                stats = jenkins_get_build_job(dashbrd, job['url'])
                if stats and stats['result']: 
                    docId = stats['version']+'-'+str(stats['build_num'])+'-'+stats['distro']+'-'+stats['edition'] 
                    testResults = jenkins_get_builtin_unitTest(dashbrd, job['url'])
                    if testResults['result']:
                        db_update_test_result(testResults)
                        db_build_attach_unitTest(testResults['docId'], stats['edition'])
                    jobResult = dashbrd.update_build_job_result(curBuild, docId, stats['result'], stats['duration'], testResults)
                    db_update_build_job_result(docId, jobResult, stats['duration'], testResults['docId'])
                    completedJobs.append(job['url'])
                    logger.debug("{0} Completed Jenkins job {1} result={2}".format(dname, len(completedJobs), stats['result']))
        else:
            logger.info("{0} Unsupported Jenkins job type {1}".format(dname, gitType))

        # Health check for irregular failure such as hang and stop monitor current set of builds
        health = "" 
        health = dashbrd.health_check(curBuild)
        if health:
            logger.debug("{0} Build {1} health issue: {2}".format(dname, parentBldNum, health)) 
        else:
            logger.debug("{0} Build {1} no health issue".format(dname, parentBldNum)) 

        if health == 'pending':
            inQueue = False
            jobs = []
            for url in buildUrls:
                if jenkins_job_queue_not_empty(url):
                   inQueue = True
                   break
            if inQueue:
                # Allow Jenkins queued jobs to transition to running state 
                logger.debug("{0} Build job transitioning sleep 2 min...".format(dname))
                time.sleep(120)
                continue
            else:
                # Jenkins jobs possibly in transition or Jenkins job history no longer exists
                # Need to handle the corner case between these 2 cases and proceed
                time.sleep(300)
                if dashbrd.build_empty(curBuild):
                    logger.debug("{0} Retry - Zero jobs executed for build {1}".format(dname, parentBldNum))
                    continue
                else:
                    health = 'finished'

        if not jobList and health != 'pending':
            # checkpoint - make sure build jobs are completed
            bldResult = dashbrd.update_build_result(curBuild)
            if bldResult == "incomplete":
                logger.warning("{0} Build {1} is missing some jobs".format(dname, parentBldNum))
            else:
                logger.debug("{0} Build {1} finished result: {2}".format(dname, parentBldNum, bldResult))

            del completedJobs[:]

            # Update parent build in DB
            db_update_build_result(curBuild, bldResult)

            # If still has build in queue, then continue to next build 
            nextBuildNum = dashbrd.get_next_build()
            if nextBuildNum:
                curBuild = dashbrd.get_current_build()
                parentBldNum = nextBuildNum 
            else:
                dashbrd.stop_monitor()

            dashbrd.reset_build_result()

            logger.debug("{0} Next build {1}  dashboard: {2}".format(dname, nextBuildNum, dashbrd.getState()))
        else:
            # Jenkins jobs in progress 
            logger.debug("{0} Build job in progress sleep 60 secs...".format(dname))
            time.sleep(60)

    logger.debug("{0} thread ended...".format(ct))
    threadPools.remove(ct)


def dashboard_spinup(dashbrd):
    # Spin up one monitoring thread per dashboard instance
    dname = dashbrd.getName()
    logger.debug("{0} dashboard spin up state {1}".format(dname, dashbrd.getState()))
    if dashbrd.getState() != "monitoring":
            dname = dashbrd.getName()
            t = findThreadByName(dname)
            if t is None:
                d = threading.Thread(name=dname, target=dashboard_monitor, args=(dashbrd,))
                d.setDaemon(True)
                nt = buildThreads()
                nt.parent = d
                threadPools.append(nt)
                d.start()
                logger.debug("{0} dashboard started".format(dname))


def buildboard_reload_config(configJson):
    result = True
    # Reload and update configuration changes
    return result


# Add a Dashboard instance per build product
def buildboard_startup(cfg):
    dashbrd = Dashboard(cfg)

    name = dashbrd.getName()
    branch = dashbrd.getBranch()
    logger.info("name: {0}  branch: {1}".format(name, branch)) 

    # Initialize git repo
    repo = dashbrd.getRepo()
    gitProj = dashbrd.getBuildProject()
    if gitProj:
        if not os.path.exists(gitProj):
            check_call(["git", "clone", repo+'/'+ gitProj])
        gitRepo = Repo(gitProj)
        if gitRepo:
            dashbrd.setPyGitRepo(gitRepo)
        else:
            print ("Error: Unable to clone {0}".format(cfg['gitProj']))
            return None
    else:
        print ("Error: Need to specify the github project")
        return None


    #
    # Add build product to dashboard.html
    #
    ret = html_update_dashboard_table(cfg['name'])
    if ret:
        # Load last build from DB and update dashboard instance
        # Load last build from DB and start monitoring
        # Do nothing for now 
        print ("DEBUG: Created table {0} in Dashboard".format(cfg['name']))
    else:
        print ("WARNING: Can't add {0} to Dashboard".format(cfg['name']))
        return None

    return dashbrd


def buildboard_init(configJson):
    config = []

    # Parse config file for each build instance
    logger.debug(configJson)
    cfgFile = os.path.abspath(configJson)
    if os.path.exists(cfgFile):
        with io.open(cfgFile) as cfg:
            config = json.load(cfg)
    else:
        logger.error("Error reading configuration file {0}".format(configFile))
        sys.exit(1)

    dashboard_cfg = config['dashboard']

    logger.info("Total dashboard instances detected: {0}".format(len(dashboard_cfg)))

    # Create dashboard instance and setup for monitoring
    for cfg in dashboard_cfg:
        dashbrd = buildboard_startup(cfg)
        if dashbrd:
            dashboardPool.append(dashbrd)

    logger.info("Total dashboard instances created: {0}".format(len(dashboardPool)))
    return (len(dashboardPool))


def signal_term_handler(signal, frame):
    shutdown()
    sys.exit(0)


def main (configJson):
    nBuilds = 0

    # Initialize each dashboard instance
    nBoards = buildboard_init(configJson)
    if nBoards == 0:
        sys.exit(0)

    for dshbrd in dashboardPool:
        name = dshbrd.getName()
        parentUrl = dshbrd.getParentUrl()
        buildUrl = dshbrd.getBuildUrl()
        logger.debug("{0} ParentUrl: {1}".format(name, parentUrl))
        logger.debug("{0} BuildsUrl: {1}".format(name, buildUrl))

    try:
        signal.signal(signal.SIGTERM, signal_term_handler)
        while (True):
            for dshbrd in dashboardPool:
                mode = dshbrd.getMode()
                method = dshbrd.getMethod()
                if mode == "poll":
                    if method == "jenkins":
                        nBuilds = jenkins_scan_builds(dshbrd)
                    else:
                        nBuilds = github_scan_builds(dshbrd)
                if nBuilds:
                    dashboard_spinup(dshbrd)
                    nBuilds = 0

                jenkins_scan_unitTest(dshbrd)
                  
            logger.debug("Main Sleeping 600...")
            time.sleep(20)
            
    except KeyboardInterrupt:
        shutdown()
    

if __name__ == "__main__":
    parser = OptionParser()
    parser.add_option("-c", "--config", dest="config_file", default="config.json",
                      metavar="JSON FILE", help="JSON FILE settings for each codename/branch")
    parser.add_option("-l", "--log_level", dest="log_level", default="ERROR",
                      help="Supported levels are ERROR, WARNING, INFO, DEBUG")

    (options, args) = parser.parse_args()
    enable_logging(options.log_level)
    main(options.config_file)
