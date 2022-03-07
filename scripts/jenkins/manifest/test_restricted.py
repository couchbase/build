#!/usr/bin/env python

import argparse
import subprocess
import os
import base64

parser = argparse.ArgumentParser()
parser.add_argument("project", type=str, help="Gerrit project to check")
parser.add_argument("message", type=str, help="Commit message to check",
  nargs="?", default="")
parser.add_argument("-b", "--branch", type=str, default="master",
  help="Branch to check")
parser.add_argument("-c", "--change", type=str, default="55555",
  help="Gerrit change ID (affects output only; required for checking manifest project)")
parser.add_argument("--patchset", type=str, default="1",
  help="Gerrit patchset ID (affects output only; required for checking manifest project)")
parser.add_argument("-p", "--manifest-project", type=str,
  default="https://github.com/couchbase/manifest",
  help="Alternate Git project for manifest")
args = parser.parse_args()

scriptpath = os.path.dirname(os.path.realpath(__file__))
if args.project == "manifest":
  scriptfile = os.path.join(scriptpath, "restricted-manifest-check")
else:
  scriptfile = os.path.join(scriptpath, "restricted-branch-check")
env = os.environ
refspec = "refs/changes/{}/{}/{}".format(
  args.change[-2:], args.change, args.patchset)
env.update({
    "GERRIT_PROJECT": args.project,
    "GERRIT_BRANCH": args.branch,
    "GERRIT_CHANGE_COMMIT_MESSAGE": base64.b64encode(args.message),
    "GERRIT_HOST": "review.couchbase.org",
    "GERRIT_PORT": "29418",
    "GERRIT_REFSPEC": refspec,
    "GERRIT_CHANGE_URL": "http://review.couchbase.org/{}".format(args.change),
    "GERRIT_PATCHSET_NUMBER": args.patchset,
    "GERRIT_EVENT_TYPE": "comment-added"
    })
retval = subprocess.call([scriptfile, "-p", args.manifest_project], env=env)
print "\n\nReturn code from restricted-branch-check: {}".format(retval)

