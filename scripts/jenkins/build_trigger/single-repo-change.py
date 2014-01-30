#!/usr/bin/env python

import copy
import os.path
from subprocess import check_output
import sys
import xml.etree.ElementTree as ET
from xml.etree.ElementTree import tostring

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
    version = sys.argv[2]

    # Request current fixed-revision manifest from repo
    curr_manifest_xml = check_output(["repo", "manifest", "-r"])
    curr_manifest = ET.fromstring(curr_manifest_xml)

    # Open known-good manifest; initialize last-build and candidate
    # manifests
    good_manifest_file = os.path.join(mani_dir,
                                      "{}-good.xml".format(version))
    good_manifest = ET.ElementTree(file=good_manifest_file)

    last_manifest_file = os.path.join(mani_dir,
                                      "{}-last.xml".format(version))
    last_manifest = init_last_manifest(last_manifest_file, good_manifest)

    cand_manifest_file = os.path.join(mani_dir,
                                      "{}-cand.xml".format(version))

    # Search for a change between last-build-attempt and current
    changed_proj = None
    last_proj = None
    for proj in curr_manifest.findall("project"):
        proj_name = proj.attrib["name"]
        proj_rev = proj.attrib["revision"]
        last_proj = last_manifest.find('project[@name="{}"]'.format(proj_name))
        if last_proj == None or (proj_rev != last_proj.attrib["revision"]):
            # Found a change! Remember project name and stop iterating
            changed_proj = proj_name
            break
    else:
        # Didn't find a change - all done for this pass
        print "Did not find a changed project in manifest!"
        return 2

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
    # with the only change being the current version of changed_proj
    good_proj = good_manifest.find('project[@name="{}"]'.format(changed_proj))
    if good_proj == None:
        # Insert new project
        good_manifest.getroot().append(proj)
    else:
        good_proj.attrib["revision"] = proj_rev

    # Write candidate to disk
    good_manifest.write(cand_manifest_file)

    # Update github
    os.chdir(mani_dir)
    print check_output(["git", "add", "-A"])
    print check_output(["git", "commit", "-m",
                        "{}".format(os.environ["BUILD_TAG"])])
    print check_output(["git", "push", "origin"])


if __name__ == '__main__':
    sys.exit(main())
