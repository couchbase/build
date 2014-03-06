#!/usr/bin/env python2.6

# Copyright (c) 2010, Code Aurora Forum. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#    # Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#    # Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#    # Neither the name of Code Aurora Forum, Inc. nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
# ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# This script is designed to detect when a patchset uploaded to Gerrit is
# 'identical' (determined via git-patch-id) and reapply reviews onto the new
# patchset from the previous patchset.

# Get usage and help info by running: ./trivial_rebase.py --help
# Documentation is available here: https://www.codeaurora.org/xwiki/bin/QAEP/Gerrit

import json
from optparse import OptionParser
import subprocess
from sys import exit
import re

def SuExec(server, port, private_key, as_user, cmd):
  suexec_cmd = ['ssh', '-l', "Gerrit Code Review", '-p', port, server, '-i',
                private_key, 'suexec', '--as', as_user, '--', cmd]
  CheckCall(suexec_cmd)

class CheckCallError(OSError):
    """CheckCall() returned non-0."""
    def __init__(self, command, cwd, retcode, stdout, stderr=None):
        OSError.__init__(self, command, cwd, retcode, stdout, stderr)
        self.command = command
        self.cwd = cwd
        self.retcode = retcode
        self.stdout = stdout
        self.stderr = stderr

def CheckCall(command, cwd=None):
    """Like subprocess.check_call() but returns stdout.
        
        Works on python 2.4
        """
    try:
        process = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE)
        std_out, std_err = process.communicate()
    except OSError, e:
        raise CheckCallError(command, cwd, e.errno, None)
    if process.returncode:
        raise CheckCallError(command, cwd, process.returncode, std_out, std_err)
    return std_out, std_err

def Main():
    server = 'localhost'
    usage = "usage: %prog <required options> [--server-port=PORT]"
    parser = OptionParser(usage=usage)
    parser.add_option("--change", dest="changeId", help="Change identifier")
    parser.add_option("--project", help="Project path in Gerrit")
    parser.add_option("--branch", help="[ignored]")
    parser.add_option("--change-url", help="[ignored]")
    parser.add_option("--commit", help="Git commit-ish for this patchset")
    parser.add_option("--patchset", type="int", help="The patchset number")
    parser.add_option("--private-key-path", dest="private_key_path",
                      help="Full path to Gerrit SSH daemon's private host key")
    parser.add_option("--server-port", dest="port", default='29418',
                      help="Port to connect to Gerrit's SSH daemon "
                      "[default: %default]")
    
    (options, args) = parser.parse_args()
    
    if not options.changeId:
        parser.print_help()

        exit(0)
    #
    # This code is just horrificly ugly.  Please make prettier code.
    #

    #find out if commit message has MB- or CBD- for ep-engine , bucket-engine , couchdb , couchstore or memcached
    #and add a comment there that the committer needs to add that information to the commit message
    comment_msg = '"commit message does not contain JIRA reference(MB-,CBD-,CBQE-).please refer to http://www.couchbase.com/wiki/display/couchbase/Submitting+Code+Changes"'    
    required_projects = ["testrunner","ep-engine","couchstore","moxi","couchdb","ns_server","bucket_engine","memcached"]
    if options.project in required_projects:
        cmd = ['git', 'log', options.commit, '--pretty=oneline' ,'--abbrev-commit', '-n1']
        commit_log = CheckCall(cmd,"/home/gerrit/review_site/git/%s.git/" % (options.project))
        pattern = re.compile('^MB|CBD|CBQE')
        if not pattern.search(str(commit_log)[10:]):
           comment_cmd = ['ssh', '-p', options.port, server, 'gerrit', 'approve',
                          '--project', options.project, '--message', comment_msg, options.commit]
           CheckCall(comment_cmd)
           exit(0)

    # Check to make sure a non-generic bug id is present in memcached and bucket_engine
    required_projects = ["bucket_engine","memcached"]
    if options.project in required_projects:
        cmd = ['git', 'log', options.commit, '--pretty=oneline' ,'--abbrev-commit', '-n1']
        commit_log = CheckCall(cmd,"/home/gerrit/review_site/git/%s.git/" % (options.project))
        pattern = re.compile('^MB-100|MB-0|CBD-100|CBD-0|CBQE-100|CBQE-0')
        if pattern.search(str(commit_log)[10:]):
           comment_msg = '"commit message contains generic reference(MB-100,MB-0,CBD-100,CBD-0,CBQE-100,CBQE-0). All commits for this project must reference a valid bug ID"'
           comment_cmd = ['ssh', '-p', options.port, server, 'gerrit', 'approve',
                          '--project', options.project, '--message', comment_msg, options.commit]
           CheckCall(comment_cmd)
           exit(0)

    exit(0)

if __name__ == "__main__":
    Main()
