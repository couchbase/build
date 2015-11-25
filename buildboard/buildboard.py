#!/usr/bin/python
# coding: UTF-8 

import os
import sys
import signal
import threading
import collections
import subprocess
import logging
import time
from optparse import OptionParser
from datetime import datetime

import urllib2
import httplib
import socket
from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler
from SocketServer import ThreadingMixIn
from bs4 import BeautifulSoup

import json
from pprint import pprint

from dashboard import Dashboard
from buildHistory import buildHistory, buildJob
from buildDB import buildDB


__version__ = "1.0.0"

BLDHISTORY_BUCKET = 'couchbase://buildboard-couchbase-server:8091/build-history'

class buildThreads(object):
    parent=None
    child=None

class buildEvents(object):
    eType=None
    service=None
    params=None

logger = logging.getLogger()
log_file = "buildboard.log"

threadPools = []
issueLabels = ["CB", "MB", "SDK"]
projPrivate = ["voltron", "cbbuild"]

# Active dashboards
dashboardPool = []

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


def findDashboardByName(name):
    for dbrd in dashboardPool:
        if dbrd.getName() == name:
            break
        else:
            dbrd = None
    return dbrd

def findBuildThreads(thread):
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


#################### HTML Template Engine #####################
#
# Need to ask Flask and (Backbone/underscore)
#
def html_update_buildboard (name):
    return 0


def html_generate_dashboard_page(name):
    logger.debug("Not implemented")

    filename = "dashboard.html"
    htmlFile = os.path.dirname(os.path.abspath(__file__))+"/html/{0}".format(filename)
    return htmlFile 


def html_generate_buildHistory_page(name):

    templateFile = "file://"+os.path.abspath("")+"/templates/build_template.html"

    filename = name + ".html"
    htmlFile = os.path.dirname(os.path.abspath(__file__))+"/html/{0}".format(filename)

    if os.path.isfile(htmlFile): 
        return filename

    try:
        rsp = urllib2.urlopen(templateFile, timeout=10)
        template = rsp.read()
        rsp.close()
    except BaseException as e:
        logger.warning("Unable to read {0} error {1}".format(templateFile, e))
        return "error"
    except socket.timeout: 
        logger.warning("Can't open build history template {0}".format(templateFile))
        return "error"

    soup = BeautifulSoup(template, "html.parser")

    # Add title per product branch
    title = "Couchbase Buildboard {0} ".format(name) +"History"
    soup.title.insert(0, title)

    # Add table
    table = "<br><h2 style=color:#086a87>{0}</h2> <div class=build_table> <table> <tr> <td style=width:7%;> Build ID </td> <td style=width:8%;> Date </td> <td style=width:8%;> Issue ID </td> <td style=width:8%;> Module </td> <td style=width:9%;> Change List </td> <td style=width:10%;> Author </td> <td style=width:42%;> Commit Summary </td> <td style=width:8%;> Build Result </td> </table> </div>".format(name)

    chickenSoup = soup.findAll("body")
    table = BeautifulSoup(table, "html.parser")
    soup.body.insert(0, table)
    soup = soup.prettify(soup.original_encoding)

    try:
        file = open(htmlFile, "wb")
        file.write(soup)
        file.close()
    except BaseException as e:
        logger.warning("Unable to write {0} error {1}".format(htmlFile, e))
        return "error"

    # Add new link to buildboard.html
    html_update_buildboard(name)

    return filename


def html_buildHistory_update_status(name, status):
    filename = name + ".html"
    htmlFile = "file://"+os.path.abspath("")+"/html/{0}".format(filename)
    try:
        rsp = urllib2.urlopen(htmlFile, timeout=10)
        html = rsp.read()
        rsp.close()
    except BaseException as e:
        logger.warning("Unable to read {0} error {1}".format(filename, e))
        return False
    except socket.timeout: 
        logger.warning("Can't open build history html {0}".format(filename))
        return False

    soup = BeautifulSoup(html, "html.parser")
    col = soup.findAll("td")
        
    return True


def html_buildHistory_report(name, data):
    filename = name + ".html"
    htmlFile = "file://"+os.path.abspath("")+"/html/{0}".format(filename)
    try:
        rsp = urllib2.urlopen(htmlFile, timeout=10)
        html = rsp.read()
        rsp.close()
    except BaseException as e:
        logger.warning("Unable to read {0} error {1}".format(filename, e))
        return False
    except socket.timeout: 
        logger.warning("Can't open build history html {0}".format(filename))
        return False

    soup = BeautifulSoup(html, "html.parser")
    table = soup.findAll("tr")

    offset = 2
    row = ""
    first_row = True

    if data["status"]:
        status = data["status"]
    else:
        status = "pending" 

    value = datetime.fromtimestamp(data["timestamp"] / 1e3)
    timestamp = value.strftime('%Y-%m-%d %H:%M:%S')

    if not data["changeSet"]:
        # Top row for this build entry
        row = "<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td><td>{5}</td><td>{6}</td><td class={7}>{8}</td></tr>".format(data["buildNum"], timestamp, "NA", "NA", "NA", "NA", "NA", status, status)
        row = BeautifulSoup(row, "html.parser")
        soup.table.insert(offset, row)
    else:
        for i in data["changeSet"]:
            commit  = bldDB.query_commit(i)
            repo = commit['repo']
            issueId = commit['issueId'] 
            commitSHA = commit['commitId']
            if "title" in commit:
                commitTitle = commit['title'].encode('ascii', 'ignore')
            else:
                commitTitle = "NA"

            if "author" in commit:
                commitAuthor = commit['author'].encode('ascii', 'ignore')
            else:
                commitAuthor = "NA"

            if first_row == True:
                row = "<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td><td>{5}</td><td>{6}</td><td class={7}>{8}</td></tr>".format(data["buildNum"], timestamp, issueId, repo, commitSHA[:10], commitAuthor, commitTitle[:100], status, status)
                first_row = False
            else:
                row = "<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td><td>{5}</td><td>{6}</td><td>{7}</td></tr>".format("", "", issueId, repo, commitSHA[:10], commitAuthor, commitTitle[:100], "")
                offset += 2

            row = BeautifulSoup(row, "html.parser")
            soup.table.insert(offset, row)

    soup = soup.prettify(soup.original_encoding)

    # Need to add a limit on display depth (max rows)
    htmlFile = os.path.dirname(os.path.abspath(__file__))+"/html/{0}".format(filename)
    try:
        file = open(htmlFile, "wb")
        file.write(soup)
        file.close()
    except BaseException as e:
        logger.warning("Unable to write {0} error {1}".format(htmlFile, e))
        return False

    return True


def html_dashboard_report(name, data):
    print "Not implemented..."
    return 0


####################### Jenkins Web Crawling  ########################
#
# Uses Jenkins REST API
#
def jenkins_fetch_envVars(url):
    data = None
    envVars_url = url + "injectedEnvVars/api/json?pretty=true"
    try:
        rsp = urllib2.urlopen(envVars_url, timeout=10)
        data = json.load(rsp)
        rsp.close()
    except (httplib.BadStatusLine, urllib2.HTTPError, urllib2.URLError) as e:
        logger.warning("Warning: Unable to read Jenkins {0} at {1}".format(e, envVars_url))
    except socket.timeout: 
        logger.warning("Jenkins request timeout {0}".format(envVars_url))

    return data


def jenkins_fetch_url(url):
    data = None
    jenkins_url = url + "api/json?pretty=true"
    try:
        rsp = urllib2.urlopen(jenkins_url, timeout=10)
        data = json.load(rsp)
        rsp.close()
    except (httplib.BadStatusLine, urllib2.HTTPError, urllib2.URLError) as e:
        logger.warning("Warning: Unable to read Jenkins {0} at {1}".format(e, jenkins_url))
    except socket.timeout: 
        logger.warning("Jenkins request timeout {0}".format(jenkins_url))

    return data


def jenkins_get_manifestSHA(url, buildNum):
    manifestSHA = 0

    env_url = url + "{0}/".format(buildNum)
    envVars = jenkins_fetch_envVars(env_url)
    if envVars is None:
        return manifestSHA
    else:
        if "envMap" in envVars:
            envMap = envVars["envMap"] 

    if "MANIFEST_SHA" in envVars["envMap"]: 
        manifestSHA = envMap["MANIFEST_SHA"] 

    return manifestSHA


def jenkins_fetch_changeSet(dashbrd, buildNum, url):
    items = []
    result = {}
    changeSet = []

    # Build summary detail
    jenkinsUrl = "{0}{1}/changes#detail0".format(url, buildNum)

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
        # Jenkins seem to have a bug
        if write_data == "repo":
            if "Revision" in i:
                result["repo"] = i.replace("Revision", "")
                write_data = "commitId"
            else:
                result["repo"] = i
                write_data = ""
            # Need to handle private Project 
            if "manifest" in result["repo"]: 
                result["repo"] = u'manifest'
            else:
                proj = result["repo"].split("/")
                result["repo"] = proj[-1]
            logger.debug("{0} Repo: {1}".format(dashbrd.getName(), result["repo"]))
            continue
        if write_data == "commitId":
            if "Author" in i:
                result["commitId"] = i.replace("Author", "")
                write_data = "author"
            else:
                result["commitId"] = i
                write_data = "Null"
            logger.debug("{0} commitID: {1}".format(dashbrd.getName(), result["commitId"]))
            changeSet.append(result.copy())
            continue

        if "Project" in i:
            write_data = "repo"
        elif "Revision" in i:
            write_data = "commitId"

    # Get the remaining history from GitHub (To-Do)
    logger.debug(changeSet)

    return changeSet


def jenkins_fetch_job_history(bldHistory, url):
    """
    :type: dict
    """
    history = {}

    # Job entry point
    jenkins_jobHistory = jenkins_fetch_url(url)
    if jenkins_jobHistory is None:
        return None

    for action in jenkins_jobHistory["actions"]:
        if "parameters" in action:
            for params in action["parameters"]:
                name = params["name"]
                if name == "EDITION":
                    history["edition"] = params["value"]
                    logger.debug("{0}...{1}".format(name, params["value"]))
                if name == "DISTRO" or name == "ARCHITECTURE" or name == "OS":
                    if "platform" in history:
                        platform = history["platform"]
                        history["platform"] = platform + params["value"]
                    else:
                        history["platform"] = params["value"]
                    logger.debug("{0}...{1}".format(name, params["value"]))

    history["slave"] = jenkins_jobHistory["builtOn"]
    history["duration"] = jenkins_jobHistory["duration"]
    history["timestamp"] = jenkins_jobHistory["timestamp"]
    if jenkins_jobHistory["result"] is None:
        history["status"] = "pending" 
    else:
        history["status"] = jenkins_jobHistory["result"]

    history["branch"] = bldHistory["branch"]
    history["buildNum"] = bldHistory["buildNum"]

    logger.debug("{0}...{1}".format(history["branch"], history["status"]))

    # Update DB Job History
    docId = bldDB.insert_job_history(history)

    bldJob = buildJob(bldHistory["buildNum"], url)
    history["docId"] = docId 
    bldJob.update_db_history(history)

    return bldJob


def jenkins_find_downstream_jobs(url, parentBldNum):
    jobList = []

    logger.debug("{0}".format(parentBldNum))

    parent_url = url + "{0}/".format(parentBldNum)
    data = jenkins_fetch_url(parent_url)
    if data is None or data["result"] == "FAILURE":
        return jobList 

    downstream_projs = jenkins_fetch_url(url)
    if downstream_projs is None:
        return None

    for proj in downstream_projs["downstreamProjects"]:
        if proj["url"]:
            downstream_builds = jenkins_fetch_url(proj["url"])
            if downstream_builds is None:
                continue

            # Find downstream jobs with corresponding parentBldNum
            for build in downstream_builds["builds"]:
                jenkins_history = jenkins_fetch_url(build["url"])
                if jenkins_history is None:
                    continue

                upstreamBldNum = 0
                actions = jenkins_bldHistory["actions"]
                for action in jenkins_bldHistory["actions"]:
                    if "causes" in action:
                        upstreamBldNum = action["causes"][0]["upstreamBuild"]
                        logger.debug(upstreamBldNum)
                        break

                if parentBldNum == upstreamBldNum:
                    if build["url"] is not None:
                        jobList.append(build["url"])
                        break

            # Traverse downstream
            if downstream_builds["downstreamProjects"]:
                more_jobs = jenkins_find_downstream_jobs(proj["url"], jenkins_bldHistory["number"])
                jobList.append(more_jobs)

    return jobList


def jenkins_find_multi_build_jobs(parentBldNum, buildUrl):
    #
    # This handles multi-configuration Jenkins job. The matrix job triggered as part of Post-Build 
    # Find and return list of matrix jobs tied to the parentBldNum
    #
    jobLinks = []
    multiJobs = []

    logger.debug("Parent buildNum {0}".format(parentBldNum))

    downstream_builds = jenkins_fetch_url(buildUrl)
    if downstream_builds is None: 
        return None

    for downstream in downstream_builds["builds"]:
        logger.debug("Downstream {0}".format(downstream["url"]))
        buildNum = 0
        # Find downstream jobs with corresponding parentBldNum
        buildJob = jenkins_fetch_url(downstream["url"])
        if buildJob is not None:
            for action in buildJob["actions"]:
                if "parameters" in action:
                    for i in action["parameters"]:
                        if i["name"].upper() == "BLD_NUM":
                            buildNum = i["value"]
                            break
                    break

            logger.debug("{0} Found Job BLD_NUM {1}".format(parentBldNum, buildNum))

            if buildNum == parentBldNum:
                if downstream["url"] is not None:
                    jobLinks.append(downstream["url"])
                    continue
            elif buildNum < parentBldNum:
                break

    logger.debug("Build {0} running {1} downstream jobs".format(parentBldNum, len(jobLinks)))

    return jobLinks


def jenkins_fetch_buildHistory(dashbrd, parentBuildNum, jenkinsBuildNum):
    #
    # Jenkins subprojects needs to be part of the build process in order to traverse the links
    #

    logger.debug("parentBuildNum: {0}  jenkins: {1}".format(parentBuildNum, jenkinsBuildNum))

    parentUrl = dashbrd.getJenkinsParentUrl()
    jenkins_type = dashbrd.getJenkinsType()
    jenkins_bldHistory = {} 
    bldHistory = {}

    # Build entry point
    build_url = parentUrl + "{0}/".format(jenkinsBuildNum)
    jenkins_bldHistory = jenkins_fetch_url(build_url)
    if jenkins_bldHistory is None:
        return None
  
    actions = jenkins_bldHistory["actions"]
    for action in actions:
        if "parameters" in action:
            for i in action["parameters"]:
                name = i["name"]
                if name.upper() == "RELEASE":
                    bldHistory["codename"] = i["value"]
                    continue
                if name.upper() == "VERSION":
                    bldHistory["branch"] = i["value"]
            break

    logger.debug("{0}...{1}".format(bldHistory["codename"], bldHistory["branch"]))

    bldHistory["buildNum"] = parentBuildNum 
    bldHistory["timestamp"] = jenkins_bldHistory["timestamp"]
    bldHistory["duration"] = jenkins_bldHistory["duration"]
    bldHistory["slave"] = jenkins_bldHistory["builtOn"]
    bldHistory["manifestSHA"] = jenkins_get_manifestSHA(parentUrl, jenkinsBuildNum)
    bldHistory["changeSet"] = [] 
    bldHistory["bld_jobs"] = [] 
    bldHistory["bldJobs_docId"] = [] 

    githubType = dashbrd.getGithubType()
    githubUrl = dashbrd.getGithubUrl()

    # Get changeSet from Jenkins summary
    changeSet = jenkins_fetch_changeSet(dashbrd, jenkinsBuildNum, parentUrl)
    logger.debug(changeSet)

    nextItem = False
    # Build commit history
    for item in jenkins_bldHistory["changeSet"]["items"]:
        commitHistory = {} 
        msg = item["msg"]
        issueMsg = msg.split("\n")
        for line in issueMsg:
            for label in issueLabels:
                if label in line or "Change-Id" in line:
                    commitHistory["issueId"] = "NA" 
                    if "Change-Id" not in line:
                        issue = line.split(":")
                        issueArray = issue[0].split(" ")
                        # Just get issue ID and get additional description from (JIRA)
                        for i in issueArray:
                            for label in issueLabels:
                                if label in i:
                                    commitHistory["issueId"] = i
                                    break
                            if commitHistory["issueId"] != "NA":
                                break
                        logger.debug("issueId: {0}".format(commitHistory["issueId"]))

                    # Get complete changeSet from Jenkins and github
                    if changeSet:
                        commit = changeSet.pop(0)
                        logger.debug("Repo: {0}".format(commit["repo"]))
                        commitHistory["repo"] = commit["repo"]
                        commitHistory["commitId"] = commit["commitId"]
                        commitHistory["url"] = githubUrl+commit["repo"]+"/commit/"+commit["commitId"]
                        commitHistory["codename"] = bldHistory["codename"]
                        commitHistory["branch"] = bldHistory["branch"]
                        commitLog = github_get_commit_log(dashbrd, commit["repo"], commit["commitId"])
                        if commitLog:
                            commitHistory["author"] = commitLog["author"]
                            commitHistory["title"] = commitLog["title"]
                            commitHistory["desc"] = commitLog["desc"]
                        else:
                            logger.debug("commitLog is empty {0}".format(commitHistory["url"]))
                        docId = bldDB.insert_commit(commitHistory)
                        bldHistory["changeSet"].append(docId)

                    nextItem = True
                    break
            if nextItem == True:
                nextItem = False
                break

    # Create new set of build history 
    newBuild = buildHistory(parentBuildNum, build_url)
    newBuild.update_db_history(bldHistory)

    dbHistory = newBuild.get_db_history()
    logger.debug(dbHistory)
    # Seems to have a BUG here 
    docId = bldDB.insert_build_history(bldHistory)

    return newBuild


def jenkins_find_new_builds(dashbrd):
    #
    # Scan for all new builds since last build 
    #
    parentUrl = dashbrd.getJenkinsParentUrl()
    jenkins_type = dashbrd.getJenkinsType()
    bldList = []
    buildCount = 0

    logger.debug("{0}".format(parentUrl))

    # Parent build history 
    bld_list = jenkins_fetch_url(parentUrl)
    if bld_list is None:
        return buildCount
 
    count = 0
    max_count = 40 
    # Scan all available builds
    for build in bld_list["builds"]:
        parentBldNum = 0
        if "number" in build:
            jenkinsBldNum = build["number"]
        else:
            return buildCount

        if jenkins_type == "multi-build":
            envVars = jenkins_fetch_envVars(build["url"])
            if envVars is None:
                return buildCount

            # Get from trigger properties     
            if "BLD_NUM" in envVars["envMap"]:
                parentBldNum = envVars["envMap"]["BLD_NUM"]
            else:
                return buildCount
        else:
            parentBldNum = jenkinsBldNum 

        if dashbrd.build_is_new(parentBldNum) == True: 
            newBuild = jenkins_fetch_buildHistory(dashbrd, parentBldNum, jenkinsBldNum)
            if newBuild:
                dashbrd.add_build(newBuild)
                buildCount += 1
                logger.debug("{0} Found new build #{1}".format(dashbrd.getName(), newBuild.getBuildNum()))
            else:
                logger.warning("Build #{0} failed to start at {1}".format(parentBldNum, build["url"]))
        else:
            break 
        
        # Number of builds to fetch at initial startup
        count += 1         
        if count > max_count or parentBldNum == dashbrd.getCurrBuildNum(): 
            break

    logger.debug("{0} Discovered {1} builds...fetching new {2}".format(dashbrd.getName(), count, buildCount))

    return buildCount


#################### GITHUB Utility #####################
#
# Need to add support for Python Git module
#
def github_fetch_commit(url):
    commitLog = None
    try:
        rsp = urllib2.urlopen(url, timeout=10)
        data = rsp.read()
        commitLog = BeautifulSoup(data, "html.parser") 
        rsp.close()
    except (httplib.BadStatusLine, urllib2.HTTPError, urllib2.URLError) as e:
        logger.warning("Warning: {0} query github at {1}".format(e, url))
    except socket.timeout: 
        logger.warning("Github request timeout {0}".format(url))

    return commitLog


def github_get_commit_log(dashbrd, repo, commitId):
    commitLog = {}
    githubUrl = dashbrd.getGithubUrl()
    url = githubUrl+"{0}/commit/{1}".format(repo, commitId)

    # Need alternate method
    if repo in projPrivate:
        return commitLog
 
    log = github_fetch_commit(url)
    if log is not None:
        commitLog["desc"] = log.find("div", {"class": "commit-desc"}).text.strip()
        title = log.find("div", {"class": "commit"}).text.strip()
        title = title.split("\n")
        commitLog["title"] = title[2].lstrip()

        try:
            commitLog["author"] = log.find("a", {"rel": "contributor"}).text.strip()
        except AttributeError:
            try:
                commitLog["author"] = log.find("span", {"class": "user-mention"}).text.strip()
            except AttributeError:
                commitLog["author"] = "NA"

    logger.debug("{0}".format(commitLog))

    return commitLog
    

def github_get_manifest_changes(url, manifestSHA):
    # changeSet : [ 
    #    {
    #        "repo" : "",
    #        "commitId" : "" 
    #    }, 
    # ]
    values = []
    changeSet = []

    manifest_url = url+"build-team-manifests/commit/"+manifestSHA

    try:
        rsp = urllib2.urlopen(manifest_url, timeout=10)
        html = rsp.read()
        manifest = BeautifulSoup(html, "html.parser") 
        rsp.close()
    except (httplib.BadStatusLine, urllib2.HTTPError, urllib2.URLError) as e:
        logger.warning("Warning: {0} query github at {1}".format(e, manifest_url))
        return changeSet
    except socket.timeout: 
        logger.warning("Github request timeout {0}".format(manifest_url))
        return changeSet

    for td in manifest.findAll("td", {"class": "blob-code blob-code-addition"}):
        for span in td.findAll("span", {"class": "blob-code-inner"}):
            if "project" == span.find("span", {"class": "pl-ent"}).text.strip():
                for val in span.findAll("span", {"class": "pl-s"}):
                    val = val.text.strip()
                    if "master" not in val:
                        values.append(val)

    for i in range(len(values)):
        if i % 2:
            changeSet[i/2].update({"commitId": changes[i]})
        else:
            changeSet.append({"repo": changes[i]})

    return changeSet


######################## Buildboard Server ##############################

def shutdown ():
    logger.info("Buildboard cleanup and saving data!")

    # Gracefully stop pending threads before removing 
    if threadPools:
        del threadPools[:]
        
    # Save all running data
    for i in range(len(dashboardPool)):
        dashbrd = dashboardPool.pop()
        dashbrd.close()


def dashboard_watch_build_job(dashbrd, buildJob):
    jobHistory = {}
    result = "pending"
    build_url = buildJob.getJenkinsUrl()
    timer = 600
    timeout = timer
#    timeout_limit = dashbrd.getTimeout()
    timeout_limit = 3600
    data = None

    dashbrd.build_job_start(buildJob, result)
    logger.debug("{0} Start watching...{1}...{2}".format(dashbrd.getName(), build_url, dashbrd.getTimeout()))

    while result == "" or result == "pending":
        # Monitor each set of running jobs
        logger.warning("Watching...{0} timeout in {1} seconds".format(build_url, timeout_limit))
        data = jenkins_fetch_url(build_url)
        if data is not None and data["result"]:
            result = data["result"]
        else:
            # Get build job duration to determine timeout value 
            if timeout <= timeout_limit:
                time.sleep(timer)
                timeout += timer
            else:
                # Need to diagnose or flash alert due to posible hang in Jenkins 
                logger.warning("Job timeout: {0}".format(build_url))
                logger.warning("{0} Job RESULT: {1}".format(dashbrd.getName(), data["result"]))
                result = "TIMEOUT" 

    # Build job ended
    logger.debug("{0} Stop watching...{1}".format(dashbrd.getName(), build_url))
    dashbrd.build_job_end(buildJob, result)

    buildJob.setDuration(data["duration"])
    jobHistory = buildJob.get_db_history()
    bldDB.update_job_history(jobHistory)

    # Update Dashboard
    logger.debug("Need to update Dashboard")


def dashboard_monitor(dashbrd):
    # 
    # Monitor threads per build job 
    #   - process live running data
    #   - health of active builds
    #   - update web contents
    # 
    currBuild = dashbrd.get_next_build()
    (state, buildStatus) = dashbrd.start(currBuild)
    parentBuildNum = currBuild.getBuildNum()
 
    t = threading.currentThread()
    tname = t.getName()
    name = dashbrd.getName()
    logger.debug("{0} thread {1} {2} {3}".format(name, tname, t, state))

    tp = findBuildThreads(t)
    tp.child = []
    
    jenkins_type = dashbrd.getJenkinsType()
    parentUrl = dashbrd.getJenkinsParentUrl()
    buildUrls = dashbrd.getJenkinsBuildUrl()

    count = 0 
    jobList = []
    pendingJobs = []

    # Need to check for thread Queue for incoming build 
    while state == "running" and buildStatus == "pending":
        count += 1 
        logger.debug("{0} Sanity check...loop: {1}".format(name, count))

        # Downstream jobs discovery 
        if jenkins_type == "multi-build":
            bldHistory = currBuild.get_db_history()   
            for url in buildUrls:
                jobList = jenkins_find_multi_build_jobs(parentBuildNum, url)
                for job_url in jobList:
                    if currBuild.job_is_new(job_url):
                        newJob = jenkins_fetch_job_history(bldHistory, job_url)
                        if newJob is not None:
                            currBuild.add_job(newJob)
        elif jenkins_type == "single-build":
            jobList = jenkins_find_downstream_jobs(parentUrl, parentBuildNum)
            if jobList:
                for job in jobList:
                    if currBuild.job_is_new(job_url):
                        newJob = jenkins_fetch_job_history(bldHistory, job["url"])
                        if newJob is not None:
                            currBuild.add_job(newJob)
        else:
            logger.info("{0} Unknown Jenkins build type {1}".format(name, jenkins_type))

        if jobList:
            del jobList[:]

        pendingJobs = currBuild.get_pending_jobs()
        logger.debug("{0} Pending Jobs: {1}".format(name, len(pendingJobs)))

        if pendingJobs:
            # Monitor each running job
            for job in pendingJobs:
                data = None
                # Don't schedule if job is already being watched 
                if dashbrd.watching(job) == False:
                    data = jenkins_fetch_url(job.getJenkinsUrl())
                    if data is None or not data["result"] or data["result"] == "":
                        t = threading.Thread(target=dashboard_watch_build_job, args=(dashbrd, job))
                        tp.child.append(t)
                        t.start()
            for child in tp.child:
                if child.isAlive():
                    t.join(float(dashbrd.getTimeout()))
            if tp.child:
                del tp.child[:]

            # Allow Jenkins queue jobs to transition from pending state. Ideally query Jenkins job queue
            del pendingJobs[:]
            time.sleep(360)
        else:
            # checkpoint
            buildStatus = dashbrd.update_build_status(currBuild)

            if buildStatus == "pending": 
                # Corresponding build jobs no longer availabe in Jenkins 
                # Set to "unknown" if build does not already exist in DB
                dbHistory = bldDB.query_buildHistory(bldHistory)
                if dbHistory and "status" in dbHistory:
                    buildStatus = dbHistory['status']
                else:
                    buildStatus = "unknown"
                dashbrd.setBuildStatus(buildStatus)

            dashbrd.finish(currBuild)

            # Update DB and Web contents 
            currBuild.setStatus(buildStatus)
            bldHistory = currBuild.get_db_history()
            bldDB.update_build_history(bldHistory)
            html_buildHistory_report(dashbrd.getName(), bldHistory)

            # If more build pending in queue, continue to next build 
            currBuild = dashbrd.get_next_build()
            if currBuild is not None:
                (state, buildStatus) = dashbrd.start(currBuild)
                parentBuildNum = currBuild.getBuildNum()
                logger.debug("{0} Next build {1}  state: {2}  status: {3}".format(name, parentBuildNum, state, buildStatus))

    logger.debug("{0} thread ended...".format(tp))
    threadPools.remove(tp)


def httpPostHandler():
    return 0


def buildboard_handler(service, params):
    return 0


def dashboard_handler(service, params):
    #
    # :param service - action to perform
    #
    count = 0

    dashbrd = findDashboardByName(params[0])
    logger.debug("{0}...{1}".format(service, dashbrd.getName()))

    #
    # params["name"] = dashboard name
    #
    if dashbrd is None:
        return "unknown"

    if (service == "SCAN_BUILD"):
        count = jenkins_find_new_builds(dashbrd)
    else:
        return "Unknown event service" 

    # Spin up one monitoring daemon per dashboard
    if count:
        if dashbrd.getState() == "ready":
            dname = dashbrd.getName()
            t = findThreadByName(dname)
            if t is None:
                d = threading.Thread(name=dname, target=dashboard_monitor, args=(dashbrd,))
                d.setDaemon(True)
                nt = buildThreads()
                nt.parent = d
                threadPools.append(nt)
                d.start()


def dashboard_startup(cfg):
    # Create dashboard
    dashbrd = Dashboard(cfg["name"], cfg["init-param"])
    dashboardPool.append(dashbrd)

    # Create dashboard
    #
    name = html_generate_dashboard_page(cfg["name"])
    if name:
        dashbrd.setHtmlDashboard(name)

    # Find and load recent incomplete builds in DB and update dashboard
    #
    bldDB.retrieve_incomplete_builds(cfg["name"])

    # Find and load last successful build in DB if not exist 
    if dashbrd.getLastSuccessfulBuild() == 0:
        bldNum = bldDB.find_prev_build(cfg["name"], "lastSuccessfulBuild")
        if bldNum != 0:
            dashbrd.setLastSuccessfulBuild(bldNum)

    # Find and load last build that passed validation in DB

    dashbrd.start()

    return dashbrd


def buildValiation_handler(service, params):
    #
    # :param service - action to perform
    # :param params - list of input parameters 
    #
    return 0


def check_for_events():
    # 
    # In general, check incoming events/messages and defer processing to actual monitoring threads 
    #     :param event_type (dashboard, buildHistory, build_validation, diagnostics, etc...)
    #     :param service (ADD_BUILD, ADD_JOB, ADD_COMMIT, etc...)
    # 
    # For now, actively query Jenkins for new builds and related jobs. 
    # 

    eventQ = [] 
    eventMsgs = [] 

    # 
    # Check and store incoming messages 
    # 

    # Check dashboard events
    for dbrd in dashboardPool:
        logger.debug(dbrd.getName())

    for i in range(len(dashboardPool)):
        method = dashboardPool[i].getMethod()
        name = dashboardPool[i].getName()
        if method == "pull":
            eventQ.append(buildEvents())
            eventQ[i].eType = "dashboard" 
            eventQ[i].service = "SCAN_BUILD" 
            eventQ[i].params = []
            eventQ[i].params.append(name)
            logger.debug("Event notification {0}: {1} {2} {3}".format(i, eventQ[i].params, eventQ[i].eType, eventQ[i].service))
        elif method == "push":
            # Read incoming messages in evenMsgs and put in eventQ
            logger.debug("Check incoming messages for {0}".format(name))
        else:
            logger.debug("No event detected for {0}".format(name))
        
    return eventQ


def buildboard_init(cfg_data):
    dashboard_cfg = cfg_data["dashboard"]

    logger.info("Number of dashboards: {0}".format(len(dashboard_cfg)))

    # Generate html files from template if not exist
    for cfg in dashboard_cfg:
        dashbrd = dashboard_startup(cfg)
        filename = html_generate_buildHistory_page(cfg["name"])
        if filename:
            dashbrd.setHtmlBuildHistory(filename)


def signal_term_handler(signal, frame):
    shutdown()
    sys.exit(0)


def main (configFile):
    cfgData = []
    # Parse from config file and allow adding new dashboard instance dynamically
    logger.debug(configFile)
    try:
        cfg = open(configFile)
        cfgData = json.load(cfg)
        logger.debug(cfgData)
        cfg.close()
    except BaseException as e:
        logger.error("Error reading {0} error {1}".format(configFile, e))
        raise

    # Initialize each dashboard instance
    buildboard_init(cfgData)

    for dbrd in dashboardPool:
        name = dbrd.getName()
        htmlDashboard = dbrd.getHtmlDashboard()
        htmlBuildHistory = dbrd.getHtmlBuildHistory()
        jenkinsParentUrl = dbrd.getJenkinsParentUrl()
        jenkinsBuildUrl = dbrd.getJenkinsBuildUrl()
        logger.debug("{0}...{1}...{2}...{3}".format(name, htmlDashboard, htmlBuildHistory, jenkinsParentUrl))

    # Spin up a daemon
    try:
        signal.signal(signal.SIGTERM, signal_term_handler)
        while (True):
            event_queue = check_for_events()
            for event in event_queue:
                logger.debug("Incoming event...{0}".format(event.params[0]))
                if event.eType == "buildboard":
                    buildboard_handler(event.service, event.params)
                elif event.eType == "dashboard":
                    dashboard_handler(event.service, event.params)
                elif event.eType == "build_validation":
                    buildValidation_handler(event.service, event.params)
                else:
                    logger.info("Unknown event...")

            if event_queue:
                del event_queue[:]

            logger.debug("Sleeping 1200...")
            time.sleep(1200)
            
    except KeyboardInterrupt:
        shutdown()
    

if __name__ == "__main__":
    parser = OptionParser()
    parser.add_option("-c", "--config", dest="config_file", default="config.json",
                      metavar="JSON FILE", help="JSON FILE settings for each codename/branch")
    parser.add_option("-l", "--log_level", dest="log_level", default="DEBUG",
                      help="Supported levels are ERROR, WARNING, INFO, DEBUG")

    (options, args) = parser.parse_args()
    enable_logging(options.log_level)
    bldDB = buildDB(BLDHISTORY_BUCKET)
    main(options.config_file)
