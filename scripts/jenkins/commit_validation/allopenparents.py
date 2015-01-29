#!/usr/bin/env python

"""
Prints Change-Ids of not yet merged parent commits.

The input is a commit SHA-1. The Gerrit REST API will then be requested
to find all parent commits. Their Change-IDs will be printed to stdout.

The parent commits are traversed breadth-frist in case there are several
parents.

The output format is one Change-Id per line.
"""

import json
import urllib2 as request
import sys

GERRIT_ROOT = 'http://review.couchbase.org/'
# Gerrit responses start with ")]}'\n"
MAGIC_PREFIX_OFFSET = 5


def parse_response(response):
    """Parses a response from a Gerrir REST API request.
    """
    return json.loads(response.read()[MAGIC_PREFIX_OFFSET:])

def parent_commits(sha1):
    """Return the parent commit (SHA1) of the given one.

    Return the parent commit only if it is not yet merged.
    """
    url = (GERRIT_ROOT + 'changes/?o=CURRENT_REVISION&o=CURRENT_COMMIT' +
           '&q=status:open+' + sha1)
    resp = request.urlopen(url)
    try:
        change = parse_response(resp)[0]
    except IndexError:
        return []

    parents = change['revisions'][change['current_revision']]\
            ['commit']['parents']
    commits = [c['commit'] for c in parents]
    return commits

def all_parent_commits_and_self(sha1):
    """Return all not yet merged parent commits and itself.

    The parents are traversed recursively breadth-first in case there
    are several parents.
    """
    pos = 0
    commits = [sha1]
    while pos < len(commits):
        sha1 = commits[pos]
        commits += parent_commits(sha1)
        pos += 1
    return commits

def commit_to_change_id(sha1):
    """Return the Change-Id to the corresponding commit.
    """
    url = GERRIT_ROOT + 'changes/?q=' + sha1
    resp = request.urlopen(url)
    change = parse_response(resp)[0]
    return change['change_id']

def all_parent_change_ids(sha1):
    """Return all Change-Ids of the current commit and its parents.

    It will only include changes that are not yet merged.
    """
    commits = all_parent_commits_and_self(sha1)
    change_ids = [commit_to_change_id(c) for c in commits]
    return change_ids


def main():
    if len(sys.argv) == 1:
        print 'usage: ./allopenparents.py commit-sha-1'.format()
        exit(1)

    commit_sha1 = sys.argv[1]
    for change_id in all_parent_change_ids(commit_sha1):
        print(change_id)


if __name__ == '__main__':
    sys.exit(main())
