#!/usr/bin/python

from flask import Flask, render_template
import os, sys, json
from datetime import datetime
import time

from . import buildHistory
from util.buildDBI import *

JIRA_URL = "https://issues.couchbase.com/browse/"

@buildHistory.route('/<release>/<version>')
def spock(release, version):
    bh = []
    title = {}
    bh = get_recent_build_history(version, 10)
    if not bh:
        title['release'] = release 
        title['version'] = version 
        bh.append(title)
    return render_template('buildHistory.html', buildHistory=bh)

@buildHistory.route('<release>/buildDetails/<version>/<build_num>')
def buildDetails(release, version, build_num):
    bh = []
    bh = get_build_details(version, build_num)
    return render_template('buildDetails.html', buildHistory=bh)


def get_build_details(version, build_num):
    buildHistory = []
    buildList = []
    pbh = {}

    buildList = db_get_builds_by_number(version, int(build_num))

    nBuilds = 0 
    for build in buildList:
        # First index is the only parent build 
        if build['jobType'] == 'parent_build': 
            pbh['build_num'] = build['version']+'-'+build_num
            pbh['binUrl'] = build['binary']
            pbh['parentUrl'] = build['jenkinsUrl']
        elif build['jobType'] == 'distro_level_build': 
            bh = {}
            nBuilds += 1 
            if nBuilds > 1:
                bh['build_num'] = ""
                bh['parentUrl'] = "" 
                bh['timestamp'] = "" 
            else:
                bh['build_num'] = pbh['build_num']
                bh['parentUrl'] = pbh['parentUrl']
                # Time conversion readable format
                ts = datetime.fromtimestamp(build['timestamp'] / 1e3)
                bh['timestamp'] = ts.strftime('%Y-%m-%d %H:%M:%S')

            bh['binary'] = ""
            if "result" in build and build['result']:
                bh['bldResult'] = build['result']
                if bh['bldResult'] == "passed":
                    bh['binUrl'] = pbh['binUrl']+'/'+build_num
                elif not bh['bldResult']:
                    bh['bldResult'] = "pending"
            else:
                bh['bldResult'] = "pending"

            bh['jenkinsUrl'] = build['jenkinsUrl']
            bh['edition'] = build['edition']
            bh['platform'] = build['distro']
            bh['unitTest'] = "" 
            bh['testReport'] = ""
            if 'unitTest' in build and build['unitTest']:
                testDoc = db_doc_exists(build['unitTest'])
                if testDoc:
                    if bh['unitTest'] != "FAILED":
                        bh['unitTest'] = testDoc.value['result']
                    if bh['unitTest']:
                        bh['unitTestReportUrl'] = testDoc.value['testReportUrl']
            bh['sanity'] = "NA"
            buildHistory.append(bh)

    return buildHistory


def get_recent_build_history(version, limit):
    # Retrieve last 20 parent buildHistory
    buildList = []
    buildHistory = []

    buildList = db_get_builds_by_type(version, "parent_build", limit)

    for build in buildList:
        bh = {}
        bh['release'] = build['release']
        bh['version'] = build['version']
        bh['build_num'] = build['build_num']
        bh['jenkinsUrl'] = build['jenkinsUrl']

        # Time conversion readable format
        ts = datetime.fromtimestamp(build['timestamp'] / 1e3)
        bh['timestamp'] = ts.strftime('%Y-%m-%d %H:%M:%S')
        bh['bldResult'] = build['result']
        bh['binary'] = ""
        if not bh['bldResult']:
            bh['bldResult'] = "pending"
        else:
            if bh['bldResult'] != "failed":
                bh['binUrl'] = build['binary']+'/'+str(bh['build_num'])

        bh['unitTest'] = "NA" 
        if 'unitTest' in build and build['unitTest']:
            for test in build['unitTest']:
                testDoc = db_doc_exists(test)
                if testDoc:
                    if bh['unitTest'] != "FAILED":
                        bh['unitTest'] = testDoc.value['result']

        bh['sanity'] = "NA"

        # Provide unit test and sanity data

        if build['commits']:
            nCommits = 0 
            for c in build['commits']:
                commit = db_doc_exists(c).value
                if commit:
                    nCommits += 1 
                    bh['commitId'] = commit['sha'][:10] 
                    bh['author'] = commit['author']['name'] 
                    bh['module'] = commit['repo'] 
                    bh['commitUrl'] = commit['url']
                    bh['message'] = commit['message'][:100]
                    bh['jiraUrl'] = JIRA_URL 
                    bh['fixes'] = []
                    for fix in commit['fixes']:
                        bh['fixes'].append(str(fix))

                    if nCommits > 1:
                        bh['build_num'] = "" 
                        bh['jenkinsUrl'] = ""
                        bh['timestamp'] = ""
                        bh['bldResult'] = ""
                        bh['unitTest'] = ""
                        bh['sanity'] = ""
                    buildHistory.append(bh.copy())
        else:
            bh['commitID'] = ""
            bh['author'] = ""
            bh['module'] = ""
            bh['commitURL'] = ""
            bh['fixes'] = ""
            bh['jiraUrl'] = ""
            bh['message'] = ""
            buildHistory.append(bh.copy())

    return buildHistory

