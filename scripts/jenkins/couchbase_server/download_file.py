#!/usr/bin/python
# a simple script to download a file from an URL if the file exists
# as simple as it sounds, there is nothing like this on windows
# command line short of installing wget for windows on the VM

import sys
import urllib2

#if these args are not set, just let it throw error
#thus automatically failing the script
url=sys.argv[1]
local_file=sys.argv[2]

try:
    f = urllib2.urlopen(url)
except:
    # if file doesn't exist it is ok
    sys.exit(0)

with open(local_file, "wb") as exefile:
    exefile.write(f.read())
