#!/usr/bin/env python

"""
Simple program to update the membasex.xml file for appcast.couchbase.com
(used for macOS installs)

Note that s3cmd needs to be installed on the system this is run from, along
with a proper config file available for it (for authentication)
"""

import os.path
import string
import subprocess
import sys
import urllib

from datetime import datetime


def get_date():
    """Return the current date and time in a specific format"""

    return datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')


def get_length(macos_file):
    """Get size of latest macOS file to be retrieved"""

    try:
        return urllib.urlopen(macos_file).info()['Content-Length']
    except KeyError:   # Generated if file not found on server
        print 'Unable to access URL "%s", aborting...' % (macos_file,)
        sys.exit(1)


if __name__ == '__main__':
    try:
        version = sys.argv[1]
    except IndexError:
        print 'Usage: %s <version>' % (sys.argv[0],)
        sys.exit(1)

    macos_file = 'http://packages.couchbase.com/releases/%s/' \
                 'couchbase-server-enterprise_%s-macos_x86_64.dmg' \
                 % (version, version)

    # Create file from template
    with open('membasex.xml.tmpl') as tmpl:
        xml_tmpl = string.Template(tmpl.read())

        with open('membasex.xml', 'w') as fh:
            fh.write(xml_tmpl.substitute(
                version=version, date=get_date(), file=macos_file,
                length=get_length(macos_file)
            ))

    # Upload file to S3
    try:
        subprocess.check_call(
            ['s3cmd', '-c', os.path.expanduser('~/.ssh/live.s3cfg'),
             'put', '--acl-public', 'membasex.xml',
             's3://appcast.couchbase.com/membasex.xml']
        )
    except subprocess.CalledProcessError as exc:
        print 's3cmd unsuccessful: %s' % (exc.output,)
        sys.exit(1)
