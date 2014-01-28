#!/usr/bin/env python

import sys
import xml.etree.ElementTree as ET
from xml.etree.ElementTree import tostring


def project_path(manifest, project):
    """Return the path where the project is stored

    If no path is given then the directory equals the project name
    """
    return manifest.findall('project[@name="{}"]'.format(project))[0]\
        .attrib.get('path', project)

def main():
    if len(sys.argv) <= 2:
        print 'usage: ./single-repo-change.py <prev-manifest.xml> <good-manifest.xml>'
        exit(1)

    # Identify first project that has changed since the previous build attempt
    curr_manifest = ET.ElementTree(file='.repo/manifest.xml')
    prev_manifest = ET.ElementTree(file=sys.argv[1])
    good_manifest = ET.ElementTree(file=sys.argv[2])
    changed_proj = None
    for proj in curr_manifest.findall("project"):
        proj_name = proj.attrib["name"]
        proj_rev = proj.attrib["revision"]
        prev_proj = prev_manifest.find('project[@name="{}"]'.format(proj_name))
        if prev_proj == None or (proj_rev != prev_proj.attrib["revision"]):
            changed_proj = proj_name
            break

    if changed_proj == None:
        # Didn't find a change - this should probably not happen
        print "Did not find a changed project in manifest!"
        exit(2)

    # Construct a new manifest from the known-good manifest, with the only
    # change being the current version of changed_proj
    good_proj = good_manifest.find('project[@name="{}"]'.format(changed_proj))
    if good_proj == None:
        # Insert new project QQQ
        print "Unsupported addition of new project"
    else:
        good_proj.attrib["revision"] = proj_rev
        print tostring(good_manifest.getroot())

if __name__ == '__main__':
    sys.exit(main())
