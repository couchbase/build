#!/bin/bash

# This runs on mega3
./restart_jenkinsdocker.py --mount-docker couchbasebuild/docker-slave:20171116 docker-slave-server 2995 server.jenkins.couchbase.com

