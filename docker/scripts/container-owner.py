#!/usr/bin/python

# Quick utility to name a Docker container that owns a given
# PID (as seen on the host)
import sys
import psutil
import argparse
from docker import Client

# Command-line args
parser = argparse.ArgumentParser()
parser.add_argument("pid", type=int)
args = parser.parse_args()
pid = args.pid

# Get process info
try:
    proc = psutil.Process(pid)
except psutil.NoSuchProcess:
    print "Process {0} not found!".format(pid)
    sys.exit(2)

print "Process {0} is: {1}".format(pid, proc.cmdline())

# Create a map of Docker init processes
#  key - container process 1 ID (as seen from host)
#  value - container name
cli = Client(version="auto")
containers = cli.containers()
inits = {}
for container in containers:
    info = cli.inspect_container(container=container["Id"])
    inits[ info["State"]["Pid"] ] = info["Name"][1:]

# Walk the process tree up from the specified process until we find
# a Docker init process
while True:
    if proc.pid in inits:
        print inits[proc.pid]
        break
    proc = proc.parent()
    if proc is None:
        print "Process {0} not owned by Docker".format(pid)
        break
