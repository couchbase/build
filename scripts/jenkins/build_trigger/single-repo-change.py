#!/usr/bin/env python

import copy
import os
import os.path
import urllib
from subprocess import check_output
import sys
import xml.etree.ElementTree as ET
from xml.etree.ElementTree import tostring
import datetime

"""
Creates last-build-attempt and candidate manifests, given an existing
up-to-date repo (expected to be in CWD) and a pointer to a directory
containing known-good manifest.
"""

def init_last_manifest(last_manifest_file, good_manifest):
    """
    If last-build-attempt manifest exists, open it; otherwise, initialize
    if from last-known-good manifest.
    """
    if not os.path.isfile(last_manifest_file):
        last_manifest = copy.deepcopy(good_manifest)
        last_manifest.getroot().insert(0, \
            ET.Comment("NOTE: this manifest is never built directly. It comprises a series of 'bookmarks' identifying the last tested revision of each project."))
    else:
        last_manifest = ET.ElementTree(file=last_manifest_file)

    return last_manifest

def main():
    if len(sys.argv) <= 2:
        print 'usage: ./single-repo-change.py manifest-path manifest-id'
        return 1

    mani_dir = sys.argv[1]
    release = sys.argv[2]

    # Request current fixed-revision manifest from repo
    curr_manifest_xml = check_output(["repo", "manifest", "-r"])
    curr_manifest = ET.fromstring(curr_manifest_xml)

    # Open known-good manifest; initialize last-build manifest.
    good_manifest_file = os.path.join(mani_dir,
                                      "{}-good.xml".format(release))
    good_manifest = ET.ElementTree(file=good_manifest_file)

    last_manifest_file = os.path.join(mani_dir,
                                      "{}-last.xml".format(release))
    last_manifest = init_last_manifest(last_manifest_file, good_manifest)

    # Check for candidate manifest - if it already exists, that means
    # there's a buildbot build "in flight" and we should abort
    cand_manifest_file = os.path.join(mani_dir,
                                      "{}-cand.xml".format(release))
    if os.path.isfile(cand_manifest_file):
        print "Candidate manifest file already exists - halting this run!"
        return 0

    # Search for a change between last-build-attempt and current
    changed_proj = None
    last_proj = None
    for proj in sorted(curr_manifest.findall("project"),
                       key=lambda p:
                       100 if p.attrib["name"] == "testrunner" else 1) :
        proj_name = proj.attrib["name"]
        proj_rev = proj.attrib["revision"]
        last_proj = last_manifest.find('project[@name="{}"]'.format(proj_name))
        if last_proj == None or (proj_rev != last_proj.attrib["revision"]):
            # Found a change! Remember project name and stop iterating
            changed_proj = proj_name
            break
    else:
        # Didn't find a change - all done for this pass
        print "Did not find a changed project in manifest - nothing to do!"
        return 0

    # QQQ handle project deletion as well
 
    # Copy changed project element into last_manifest, overwriting if
    # necessary, and save back to disk
    print "Found changed project {}!".format(changed_proj)
    last_root = last_manifest.getroot()
    if last_proj != None:
        last_root.remove(last_proj)
    last_root.append(proj)
    last_manifest.write(last_manifest_file)
 
    # Construct a candidate manifest from the known-good manifest,
    # with the only change being the current revision of changed_proj
    good_proj = good_manifest.find('project[@name="{}"]'.format(changed_proj))
    if good_proj == None:
        # Insert new project
        good_manifest.getroot().append(proj)
        orig_rev = "None (new project)"
    else:
        orig_rev = good_proj.attrib["revision"]
        good_proj.attrib["revision"] = proj_rev

    # Write candidate to disk
    good_manifest.write(cand_manifest_file)

    # Update github
    os.chdir(mani_dir)
    print check_output(["git", "add", "-A"])
    print check_output(["git", "commit", "-m",
                        "{}".format(os.environ["BUILD_TAG"])])
    print check_output(["git", "push", "origin"])

    # Update status HTML
    with open("status.html", "w") as f:
        f.write("<h1>Build launched</h1>\n<ul>\n")
        line = "<li>{0}: {1}</li>\n"
        f.write(line.format("Time", datetime.now().strftime("%c")))
        f.write('<li>Polling job build URL: <a href="{0}">{0}</a></li>\n'.format(os.environ['BUILD_URL']))
        f.write(line.format("Changed project", changed_proj))
        f.write(line.format("Original SHA1", orig_rev))
        f.write(line.format("Candidate SHA1", proj_rev))
        f.write("</ul>\n")

if __name__ == '__main__':
    sys.exit(main())
