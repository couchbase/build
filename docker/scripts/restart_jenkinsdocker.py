#!/usr/bin/python

import sys
import urllib2
import json
import time
import os
import argparse
import shutil
from subprocess import call, check_output

parser = argparse.ArgumentParser()
parser.add_argument("image", type=str, help="Docker image name")
parser.add_argument("slave", type=str, help="Slave name")
parser.add_argument("port", type=str, help="SSH Port to expose from container")
parser.add_argument("jenkins", type=str, help="Jenkins to connect to",
    nargs='?', default="factory.couchbase.com")
parser.add_argument("--ccache-dir", type=str, help="Host directory to mount as ~/.ccache")
parser.add_argument("--no-workspace", action="store_true", help="Skip mounting /home/couchbase/jenkins")
parser.add_argument("--mount-docker", action="store_true", help="Mount docker.sock")
parser.add_argument("--mount-dir", type=str, help="Mount local directories",
    nargs="+")
args = parser.parse_args()

image = args.image
slave = args.slave
port = args.port
jenkins = args.jenkins
mount_dirs = args.mount_dir
if mount_dirs is None:
    mount_dirs = []

devnull = open(os.devnull, "w")

# See if Jenkins thinks the slave is connected
print "Seeing if {1} is connected to Jenkins master '{0}'...".format(jenkins, slave)
slaveurl = 'http://{0}/computer/{1}/api/json?tree=offline,executors[idle],oneOffExecutors[idle]'
while True:
    response = urllib2.urlopen(slaveurl.format(jenkins, slave))
    slavedata = json.load(response)

    # If slave is "offline", fine. Otherwise, if ALL executors are "idle", fine.
    if (slavedata["offline"]):
        break
    executors = slavedata["executors"] + slavedata["oneOffExecutors"]
    if (not (False in [x["idle"] for x in executors])):
        break

    print "Slave {0} is currently busy, waiting 30 seconds...".format(slave)
    time.sleep(30)

# See if slave is running locally
print "Checking if {0} is running locally...".format(slave)
result = call(["docker", "inspect", slave], stdout=devnull, stderr=devnull)
if result == 0:
    print "Killing {0}".format(slave)

    output = check_output(["docker", "rm", "-f", slave])
    if output.strip() != slave:
        print "Stopped slave had wrong name, but continuing to start new..."

# Create/empty slave Jenkins directory.
slave_dir = "/home/couchbase/slaves/{0}".format(slave)
print "Emptying local slave directory {0}...".format(slave_dir)
if os.path.isdir(slave_dir):
    for root, dirs, files in os.walk(slave_dir, topdown=False):
        os.chmod(root, 0o777)
        for name in files:
            os.remove(os.path.join(root, name))
        for name in dirs:
            path = os.path.join(root, name)
            if (os.path.islink(path)):
                os.remove(path)
            else:
                os.rmdir(path)

# Prefer /latestbuilds etc. to /home/couchbase/latestbuilds etc.
if os.path.isdir("/latestbuilds"):
    latestbuilds = "/latestbuilds"
else:
    latestbuilds = "/home/couchbase/latestbuilds"
if os.path.isdir("/releases"):
    releases = "/releases"
else:
    releases = "/home/couchbase/releases"

# Check out the Docker network situation
output = check_output(["docker", "network", "ls", "--format", "{{ .Name }}"])
networks = output.split("\n")
if not "jenkins-slaves" in networks:
    print "Creating 'jenkins-slaves' Docker network..."
    output = check_output(["docker", "network", "create", "jenkins-slaves"])

# Start constructing the big "docker run" command
run_args = [
     "docker", "run", "--name={0}".format(slave), "--detach=true",
     "--sysctl=net.ipv6.conf.lo.disable_ipv6=0",
     "--privileged",
     "--restart=unless-stopped",
     "--net=jenkins-slaves",
     "--publish={0}:22".format(port),
     "--volume=/home/couchbase/reporef:/home/couchbase/reporef",
     "--volume=/etc/localtime:/etc/localtime",
     "--volume=/etc/timezone:/etc/timezone",
     "--volume=/home/couchbase/jenkinsdocker-ssh:/ssh",
     "--volume={}:/latestbuilds".format(latestbuilds),
     "--volume={}:/releases".format(releases)
]
if not args.no_workspace:
    run_args.append(
     "--volume=/home/couchbase/slaves/{0}:/home/couchbase/jenkins".format(slave)
    )
if args.mount_docker:
    run_args.append(
     "--volume=/var/run/docker.sock:/var/run/docker.sock"
    )
if args.ccache_dir is not None:
    if not os.path.isdir(args.ccache_dir):
        os.makedirs(args.ccache_dir)
    run_args.append(
     "--volume={0}:/home/couchbase/.ccache".format(args.ccache_dir)
    )
for mount in mount_dirs:
    (dir, path) = mount.split(':')
    if not os.path.isdir(dir):
        os.makedirs(dir)
    run_args.append(
    "--volume={0}:{1}".format(dir, path)
    )

run_args.extend([
     "--ulimit=core=-1",
     image,
     "default"
])
# Finally, create new slave container.
print "Creating new {0} container...".format(slave)
output = check_output(run_args)
print "Result: {0}".format(output)

