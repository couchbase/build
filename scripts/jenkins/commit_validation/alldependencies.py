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
from allcommits import all_commits, GERRIT_ROOT


def all_dependencies(sha1, curr_project, curr_ref):
    """Return dependencies of the current commit.

    Returns all projects that have a not yet merged commit with a
    Change-Id that equals the current commit and any of its not yet
    merged parents.

    The return value is a tuple with two dicts with the project as
    a key and a 3-tuple consisting of the project name, path and Git ref.

    The first dict is for the immediate dependencies, the second is for
    transitive dependencies through parents.
    """

    # The current commit is the first Change-Id in the list, the parents
    # come next
    change_ids = all_parent_change_ids(sha1)

    dependencies = {}
    transitive = {}

    commits = all_commits(change_ids[0], curr_project, curr_ref)
    for project, path, ref in commits:
        dependencies[project] = (project, path, ref)

    for change_id in change_ids[1:]:
        commits = all_commits(change_id, curr_project, curr_ref)
        for project, path, ref in commits:
            # Use only the most recent Change-Id of a project
            if project not in transitive:
                transitive[project] = (project, path, ref)

    transitive.update(dependencies)
    return dependencies, transitive

def ref_to_url(ref):
    parts = ref.split('/')
    return "{}#/c/{}/{}".format(GERRIT_ROOT, parts[-2], parts[-1])

def main():
    if len(sys.argv) != 4:
        print 'usage: ./alldependencies.py sha project refspec'
        exit(1)

    dependencies, transitive = all_dependencies(*sys.argv[1:])
    if not dependencies:
        sys.stderr.write('No dependencies found for sha\n')
        exit(1)
    for project, path, ref in dependencies.values():
        print '{} {} {}'.format(project, path, ref)

    # Error for any transitive dependencies
    disjoint = [transitive[x] for x in transitive if x not in dependencies]
    if disjoint:
        sys.stderr.write('ERROR: Unmerged transitive dependencies:\n')
        for project, path, ref in disjoint:
            sys.stderr.write('{}: {}\n'.format(project, ref_to_url(ref)))
        exit(1)

if __name__ == '__main__':
    sys.exit(main())
