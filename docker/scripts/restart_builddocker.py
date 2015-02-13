#!/usr/bin/python

import sys
import urllib2
import json
import time
import os
from subprocess import call, check_output

if len(sys.argv) < 3:
    print "Usage: {0} <image name> <buildslave name> [<port>]".format(sys.argv[0])
    sys.exit(2)

image = sys.argv[1]
slave = sys.argv[2]
if len(sys.argv) > 3:
    port = sys.argv[3]
else:
    port = "2201"

devnull = open(os.devnull, "w")

# See if buildbot thinks the slave is connected
print "Seeing if {0} is connected to buildbot master...".format(slave)
slaveurl = 'http://builds.hq.northscale.net:8010/json/slaves/{0}'
while True:
    response = urllib2.urlopen(slaveurl.format(slave))
    slavedata = json.load(response)

    if (not slavedata["connected"]) or (len(slavedata["runningBuilds"]) == 0):
        break

    print "Slave {0} is currently busy, waiting 60 seconds...".format(slave)
    time.sleep(60)

# See if slave is running locally
print "Checking if {0} is running locally...".format(slave)
result = call(["docker", "inspect", slave], stdout=devnull, stderr=devnull)
if result == 0:
    print "Killing {0}".format(slave)

    output = check_output(["docker", "rm", "-f", slave])
    if output.strip() != slave:
        print "Stopped slave had wrong name, but continuing to start new..."

# Finally, create new slave container
print "Creating new {0} container...".format(slave)
output = check_output(
    ["docker", "run", "--name={0}".format(slave), "--detach=true",
     "--publish={0}:22".format(port),
     "--volume=/home/couchbase/grommit:/home/buildbot/grommit",
     "--volume=/etc/resolv.conf:/etc/resolv.conf",
     image])
print "Result: {0}".format(output)


