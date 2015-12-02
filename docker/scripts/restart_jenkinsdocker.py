#!/usr/bin/python

import sys
import urllib2
import json
import time
import os
from subprocess import call, check_output

if len(sys.argv) <= 3:
    print "Usage: {0} <image name> <jenkins slave name> <ssh port> [ <jenkins host> ]".format(sys.argv[0])
    sys.exit(2)

image = sys.argv[1]
slave = sys.argv[2]
port = sys.argv[3]
try:
    jenkins = sys.argv[4]
except IndexError:
    jenkins = "factory.couchbase.com"

devnull = open(os.devnull, "w")

# See if Jenkins thinks the slave is connected
print "Seeing if {1} is connected to Jenkins master '{0}'...".format(jenkins, slave)
slaveurl = 'http://{0}/computer/{1}/api/json?tree=offline,executors[idle]'
while True:
    response = urllib2.urlopen(slaveurl.format(jenkins, slave))
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

# Finally, create new slave container.
# Note: if you get an error about the "docker-default-ptrace" AppArmor profile
# not existing, you can create it as follows (as root on the docker host) :
# 1. Copy /etc/apparmor.d/docker to /etc/apparmor.d/docker-ptrace
# 2. Edit this file to change the profile name to "docker-default-ptrace" and
#    add a line containing "ptrace," (with the trailing comma) inside the block
# 3. Run /etc/init.d/apparmor reload
print "Creating new {0} container...".format(slave)
output = check_output(
    ["docker", "run", "--name={0}".format(slave), "--detach=true",
     "--security-opt=apparmor:docker-default-ptrace",
     "--publish={0}:22".format(port),
     "--volume=/home/couchbase/reporef:/home/couchbase/reporef",
     "--volume=/etc/resolv.conf:/etc/resolv.conf",
     "--volume=/etc/localtime:/etc/localtime",
     "--volume=/etc/timezone:/etc/timezone",
     "--volume=/home/couchbase/jenkinsdocker-ssh:/ssh",
     "--volume=/home/couchbase/latestbuilds:/latestbuilds",
     image])
print "Result: {0}".format(output)


