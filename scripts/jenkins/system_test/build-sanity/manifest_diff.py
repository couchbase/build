#!/usr/bin/env python
import os
import sys
import subprocess
import xml.etree.ElementTree as ET

#
# Given two manifests, find the changelog for each project that has changed
# from the first manifest to the second
#
# ASSUMPTIONS & LIMITATIONS:
# * Assumes that repo has synced the code for all the projects relative to
#   the current directory
# * Assumes the checkout path doesn't change from one manifest to the other
# * Revision is assumed to be a SHA (not a branch name)
# * No listing for added/deleted projects
# * Assumes branch/upstream doesn't change between the two manifests
#


if len(sys.argv) < 3:
    print 'Usage: manifest_diff.py <manifest1> <manifest2>'
    print
    sys.exit(1)

manifest1=sys.argv[1]
manifest2=sys.argv[2]

manifest1_dict = {}
manifest2_dict = {}

def parse_manifest(manifest, dict_values):
    tree = ET.parse(manifest)
    projects = tree.findall('project')
    for p in projects:
        name = p.attrib['name']
        rev = p.attrib['revision']
        path = name
        if p.attrib.has_key('path'):
            path = p.attrib['path']
        dict_values[name] = (path, rev)

parse_manifest(manifest1, manifest1_dict)
parse_manifest(manifest2, manifest2_dict)

for key in manifest1_dict.keys():
    if manifest2_dict.has_key(key):
        man1 = manifest1_dict[key]
        man2 = manifest2_dict[key]
        if man1[1] != man2[1]:
            print 'CHANGELOG FOR: %s\n' %key
            command='cd {0}; git log --name-only {1}..{2}'.format(man1[0], man1[1], man2[1])
            p = subprocess.Popen(command, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, close_fds=True)
            (child_stdout, child_stdin) = (p.stdout, p.stdin)
            print child_stdout.read()
            print 
