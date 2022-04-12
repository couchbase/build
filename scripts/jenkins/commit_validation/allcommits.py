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


def project_path(manifest, project, branch=None):
    """Return the path where the project is stored

    If no path is given then the directory equals the project name
    If no project/branch can be found then it will return None

    @param manifest: XML Element Tree of the manifest to check against
    @param project: Project we're looking for the path of.
    @param branch: Which branch the current changeid is coming from.
    This will be checked against the manifest to verify the change is
    for the branch used in the manifest. If not specified then it is
    assumed the branch is correct.
    """
    default_branch = manifest.find('default').attrib.get('revision')

    entry = manifest.find('project[@name="{}"]'.format(project))
    if entry is not None:
        if branch is None or entry.attrib.get('revision', default_branch) == branch:
            return entry.attrib.get('path', project)
    return None

def parse_response(response):
    """Parses a response from a Gerrir REST API request."""
    return json.loads(response.read()[MAGIC_PREFIX_OFFSET:])

def all_commits(change_id, curr_project, curr_ref):
    """Return all commits of all projects for a given Change-Id.

    The return value is a list of 3-tuples containing the prject name,
    path and the Git ref for the checkout.
    """
    commits = []
    manifest = ET.ElementTree(file='.repo/manifest.xml')

    # If the manifest contains an include, follow it
    try:
        included_manifest = manifest.find('include').attrib.get('name')
        manifest = ET.ElementTree(file='.repo/manifests/' + included_manifest)
    except:
        pass

    # If the local manifest exists, add in its projects to the main manifest.
    try:
        local = ET.ElementTree(file='.repo/local_manifest.xml')
        for project in local.findall('project'):
            manifest.getroot().append(project)
    except IOError:
        pass

    commits.append((curr_project, project_path(manifest, curr_project), curr_ref))

    url = (GERRIT_ROOT + 'changes/?o=CURRENT_REVISION&q=status:open+' +
           change_id)
    changes = request.urlopen(url)
    for change in parse_response(changes):
        project = change['project']
        fetch = change['revisions'][change['current_revision']]['fetch']
        # The `ref` is the same for every download scheme, hence we can use
        # the first one that is there
        ref = fetch.values()[0]['ref']
        path = project_path(manifest, project, change['branch'])
        if path and project != curr_project:
            commits.append((project, path, ref))

    return commits


def main():
    if len(sys.argv) != 4:
        print 'usage: ./allcommits.py change-id project refspec'
        exit(1)

    commits = all_commits(*sys.argv[1:])
    if not commits:
        sys.stderr.write('No commits found for change-id\n')
        exit(1)
    for project, path, ref in commits:
        print '{} {} {}'.format(project, path, ref)


if __name__ == '__main__':
    sys.exit(main())
