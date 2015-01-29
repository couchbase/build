#!/usr/bin/env python

"""
Prints all projects that have a not yet merged commit with a Change-Id
that equals the current commit or any of its not yet merged parents.

The output format is one line per project with the project name,
the path to it and the ref for Git to fetch it.

The script needs to run to be run in the root directory of the
repo checkout (as the manifest file needs to be parsed to get the
paths to the projects).
"""

import sys

from allopenparents import all_parent_change_ids
from allcommits import all_commits


def all_dependencies(sha1):
    """Return dependencies of the current commit.

    Prints all projects that have a not yet merged commit with a
    Change-Id that equals the current commit or any of its not yet
    merged parents.

    The return value is a dict with the project as a key and a
    3-tuple consisting of the project name, path and Git ref.
    """
    change_ids = all_parent_change_ids(sha1)
    dependencies = {}
    # The current commit is the first Change-Id in the list, the parents
    # come next
    for change_id in change_ids:
        commits = all_commits(change_id)
        for project, path, ref in commits:
            # Use only the most recent Change-Id of a project
            if project not in dependencies:
                dependencies[project] = (project, path, ref)
    return dependencies


def main():
    if len(sys.argv) == 1:
        print 'usage: ./alldependencies.py commit-sha-1'.format()
        exit(1)

    commit_sha1 = sys.argv[1]
    dependencies = all_dependencies(commit_sha1)
    for project, path, ref in dependencies.values():
        print '{} {} {}'.format(project, path, ref)


if __name__ == '__main__':
    sys.exit(main())
