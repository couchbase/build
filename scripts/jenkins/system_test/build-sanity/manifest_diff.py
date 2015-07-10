#!/usr/bin/env python
import os
import sys
import subprocess
import xml.etree.ElementTree as ET
from optparse import OptionParser


#
# Given two manifests, find the changelog for each project that has changed
# from the first manifest to the second
# Optionally also create a file called committers_email that has email ids
# of all the committers
#
# ASSUMPTIONS & LIMITATIONS:
# * Assumes that repo has synced the code for all the projects relative to
#   the current directory
# * Assumes the checkout path doesn't change from one manifest to the other
# * Revision is assumed to be a SHA (not a branch name)
# * No listing for added/deleted projects
# * Assumes branch/upstream doesn't change between the two manifests
#


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

def main(manifest1, manifest2, create_email_file):
    manifest1_dict = {}
    manifest2_dict = {}
    email_list = []

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
                if create_email_file:
                    command="cd {0}; git log --pretty=format:'%ae' {1}..{2}".format(man1[0], man1[1], man2[1])
                    p = subprocess.Popen(command, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, close_fds=True)
                    (child_stdout, child_stdin) = (p.stdout, p.stdin)
                    output = child_stdout.read()
                    for line in output.split():
                        if line not in email_list:
                            email_list.append(line)

        if create_email_file and email_list:
            with open('committers_email', 'w') as F:
                F.write('%s' %(', '.join(email_list)))

if __name__ == '__main__':
    parser = OptionParser()
    parser.add_option("-o", "--old-manifest", dest="old_manifest",
                      help="manifest file for the previous build number", metavar="MANIFEST FILE")
    parser.add_option("-n", "--new-manifest", dest="new_manifest",
                      help="manifest file for the current build number", metavar="MANIFEST FILE")
    parser.add_option("-e", "--email-file",
                      action="store_true", dest="email_file", default=False,
                      help="create a committers_email file with emails of the committers from the generated changelog")

    (options, args) = parser.parse_args()
    if options.old_manifest and options.new_manifest:
        main(options.old_manifest, options.new_manifest, options.email_file)
