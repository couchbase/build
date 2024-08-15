#!/usr/bin/env python3

"""
Simple program to update the membasex.xml file for appcast.couchbase.com
(used for macOS installs)

Note that awscli needs to be installed on the system this is run from, along
with a proper config file available for it (for authentication)
"""

import os.path
import string
import subprocess
import sys
import urllib.request, urllib.parse, urllib.error

from datetime import datetime


def get_date():
    """Return the current date and time in a specific format"""

    return datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')


if __name__ == '__main__':
    try:
        version = sys.argv[1]
    except IndexError:
        print('Usage: %s <version>' % (sys.argv[0],))
        sys.exit(1)

    # Create file from template
    with open('membasex.xml.tmpl') as tmpl:
        xml_tmpl = string.Template(tmpl.read())

        with open('membasex.xml', 'w') as fh:
            fh.write(xml_tmpl.substitute(
                version=version, date=get_date()
            ))

    # Upload file to S3
    try:
        subprocess.check_call(
            ['aws', 's3', 'cp', 'membasex.xml',
             's3://appcast.couchbase.com/membasex.xml',
             '--acl', 'public-read']
        )
    except subprocess.CalledProcessError as exc:
        print('aws upload  unsuccessful: %s' % (exc.output,))
        sys.exit(1)
