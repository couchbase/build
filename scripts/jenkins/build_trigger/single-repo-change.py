#!/usr/bin/env python

import copy
import os.path
import sys
import xml.etree.ElementTree as ET
from xml.etree.ElementTree import tostring

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
    if len(sys.argv) <= 1:
        print 'usage: ./single-repo-change.py manifest-id'
        return 1

    # Open current and last-known-good manifests
    curr_manifest = ET.ElementTree(file='.repo/manifest.xml')
    good_manifest = ET.ElementTree(\
        file='.repo/manifests/last-known-good-{}.xml'.format(sys.argv[1]))
    last_manifest_file = '.repo/manifests/last-build-attempt-{}.xml'.\
                         format(sys.argv[1])
    last_manifest = init_last_manifest(last_manifest_file, good_manifest)

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
 
    # Construct a new manifest from the known-good manifest, with the only
    # change being the current version of changed_proj
    good_proj = good_manifest.find('project[@name="{}"]'.format(changed_proj))
    if good_proj == None:
        # Insert new project
        good_manifest.getroot().append(proj)
    else:
        good_proj.attrib["revision"] = proj_rev

    print tostring(good_manifest.getroot())

if __name__ == '__main__':
    sys.exit(main())
