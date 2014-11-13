#!/usr/bin/python

import sys
import urllib2
import json
import time
import os
from subprocess import call, check_output

if len(sys.argv) <= 3:
    print "Usage: {0} <image name> <jenkins slave name> <ssh port>".format(sys.argv[0])
    sys.exit(2)

image = sys.argv[1]
slave = sys.argv[2]
port = sys.argv[3]

# First ensure that volume-container is created
print "Checking for Jenkins volume container..."
volumect = "jenkins-volume-container"
devnull = open(os.devnull, "w")
result = call(["docker", "inspect", volumect], stdout=devnull, stderr=devnull)
if result != 0:
    print "Creating volume container..."
    output = check_output(
        ["docker", "run", "--name={0}".format(volumect),
         "--volume=/home/couchbase/reporef:/home/buildbot/reporef",
         "--volume=/etc/resolv.conf:/etc/resolv.conf",
         "ceejatec/naked-ubuntu:10.04"])

# See if Jenkins thinks the slave is connected
print "Seeing if {0} is connected to buildbot master...".format(slave)
slaveurl = 'http://factory.couchbase.com/computer/{0}/api/json?tree=offline,executors[idle]'
while True:
    response = urllib2.urlopen(slaveurl.format(slave))
    slavedata = json.load(response)

    # If slave is "offline", fine. Otherwise, if ALL executors are "idle", fine.
    if (slavedata["offline"]):
        break
    if (not (False in [x["idle"] for x in slavedata["executors"]])):
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
     "--publish={0}:22".format(port), "--volumes-from={0}".format(volumect),
     image])
print "Result: {0}".format(output)


