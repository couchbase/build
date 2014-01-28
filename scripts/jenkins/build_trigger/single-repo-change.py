#!/usr/bin/env python

import copy
import os.path
import sys
import xml.etree.ElementTree as ET
from xml.etree.ElementTree import tostring

def create_stub_manifest(manifest_file, curr_manifest):
    new_manifest = copy.deepcopy(curr_manifest)
    new_root = new_manifest.getroot()
    for project in new_root.findall('project'):
        new_root.remove(project)
    return new_manifest

def main():
    if len(sys.argv) <= 1:
        print 'usage: ./single-repo-change.py manifest-id'
        return 1

    # Open current and last-known-good manifests
    curr_manifest = ET.ElementTree(file='.repo/manifest.xml')
    good_manifest = ET.ElementTree(\
        file='.repo/manifests/last-known-good-{}.xml'.format(sys.argv[1]))

    # If last-build-attempt manifest exists, open it; otherwise, create it
    # from current, minus all projects
    prev_manifest_file = '.repo/manifests/last-build-attempt-{}.xml'.\
                         format(sys.argv[1])
    if not os.path.isfile(prev_manifest_file):
        prev_manifest = create_stub_manifest(prev_manifest_file, curr_manifest)
    else:
        prev_manifest = ET.ElementTree(file=prev_manifest_file)

    # Search for a change between last-build-attempt and current
    changed_proj = None
    for proj in curr_manifest.findall("project"):
        proj_name = proj.attrib["name"]
        proj_rev = proj.attrib["revision"]
        prev_proj = prev_manifest.find('project[@name="{}"]'.format(proj_name))
        if prev_proj == None or (proj_rev != prev_proj.attrib["revision"]):
            # Found change! Copy project element into prev_manifest, and
            # remember the changed project name
            prev_root = prev_manifest.getroot()
            if prev_proj != None:
                prev_root.remove(prev_proj)
            prev_root.append(proj)
            changed_proj = proj_name
            break
    else:
        # Didn't find a change - all done for this pass
        print "Did not find a changed project in manifest!"
        return 2
 
    print "Found changed project {}!".format(changed_proj)
 
    # Construct a new manifest from the known-good manifest, with the only
    # change being the current version of changed_proj
    good_proj = good_manifest.find('project[@name="{}"]'.format(changed_proj))
    if good_proj == None:
        # Insert new project
        good_manifest.getroot().append(proj)
    else:
        # Ensure the last-known-good revision is also different than the current
        # (it might not be if a stub last-build-attempt manifest was made)
        if good_proj.attrib["revision"] == proj_rev:
            pass # QQQ should iterate back to next changed project
        good_proj.attrib["revision"] = proj_rev

    print tostring(good_manifest.getroot())

if __name__ == '__main__':
    sys.exit(main())
