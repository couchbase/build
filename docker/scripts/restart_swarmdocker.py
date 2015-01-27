#!/usr/bin/python

import sys
import urllib2
import json
import time
import os
from subprocess import call, check_output

if len(sys.argv) <= 4:
    print "Usage: {0} <prefix> <platform> <ssh port> <jenkins master>".format(sys.argv[0])
    sys.exit(2)

prefix = sys.argv[1]
platform = sys.argv[2]
image = "ceejatec/{0}-couchbase-build".format(platform)
port = sys.argv[3]
master = sys.argv[4]

try:
    executors = sys.argv[5]
except IndexError:
    executors = 1
try:
    slave = sys.argv[6]
except IndexError:
    slave = "{0}-sherlocker-{1}".format(prefix, platform)
try:
    labels = sys.argv[7]
except IndexError:
    labels = "sherlock {0}".format(platform)

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
         "--volume=/home/couchbase/jenkinsdocker-ssh:/ssh",
         "ceejatec/naked-ubuntu:14.04"])

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

# Start swarm job
print "Starting Jenkins swarm slave in container..."
output = check_output(
    ["docker", "exec", slave, "curl", "-O", "http://maven.jenkins-ci.org/content/repositories/releases/org/jenkins-ci/plugins/swarm-client/1.22/swarm-client-1.22-jar-with-dependencies.jar"])
print "Result: {0}".format(output)
output = check_output(
    ["docker", "exec", "-d", slave,
     "su", "couchbase", "-c", "java -jar /swarm-client-1.22-jar-with-dependencies.jar -name {0} -master {1} -mode exclusive -labels '{2}' -executors {3} -fsroot /home/couchbase/jenkins".format(slave, master, labels, executors)])
print "Result: {0}".format(output)

