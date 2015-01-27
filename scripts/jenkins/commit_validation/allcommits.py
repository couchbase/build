#!/usr/bin/env python

"""
Prints all projects that have a commit with the same Change-Id.

The output format is one line per project with the project name,
the path to it and the ref for Git to fetch it.

The script needs to run to be run in the root directory of the
repo checkout (as the manifest file needs to be parsed to get the
paths to the projects).
"""

import json
import urllib2 as request
import sys
import xml.etree.ElementTree as ET


GERRIT_ROOT = 'http://review.couchbase.org/'
# Gerrit responses start with ")]}'\n"
MAGIC_PREFIX_OFFSET = 5


def project_path(manifest, project):
    """Return the path where the project is stored

    If no path is given then the directory equals the project name
    """
    return manifest.findall('project[@name="{}"]'.format(project))[0]\
        .attrib.get('path', project)

def parse_response(response):
    """Parses a response from a Gerrir REST API request."""
    return json.loads(response.read()[MAGIC_PREFIX_OFFSET:])

def all_commits(change_id):
    """Return all commits of all projects for a given Change-Id.

    The return value is a list of 3-tuples containing the prject name,
    path and the Git ref for the checkout.
    """
    commits = []
    manifest = ET.ElementTree(file='.repo/manifest.xml')
    url = (GERRIT_ROOT + 'changes/?o=CURRENT_REVISION&q=status:open+' +
           change_id)
    changes = request.urlopen(url)
    for change in parse_response(changes):
        project = change['project']
        fetch = change['revisions'][change['current_revision']]['fetch']
        # The `ref` is the same for every download scheme, hence we can use
        # the first one that is there
        ref = fetch.values()[0]['ref']
        path = project_path(manifest, project)
        commits.append((project, path, ref))
    return commits


def main():
    if len(sys.argv) == 1:
        print 'usage: ./allcommits.py change-id'.format()
        exit(1)

    change_id = sys.argv[1]
    for project, path, ref in all_commits(change_id):
        print '{} {} {}'.format(project, path, ref)


if __name__ == '__main__':
    sys.exit(main())
