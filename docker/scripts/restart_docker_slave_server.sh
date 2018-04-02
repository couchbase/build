#!/bin/bash

# This recreates server.jenkins' "docker-slave-server", a slave
# which exists only to launch one-off Docker commands. Some of
# those commands require certain directories to be mounted.
# This slave currently runs on mega3.
./restart_jenkinsdocker.py \
    --mount-dir /home/couchbase/check_missing_commits:/home/couchbase/check_missing_commits \
        /home/couchbase/check_builds:/home/couchbase/check_builds \
        /home/couchbase/repo_upload:/home/couchbase/repo_upload \
    --mount-docker \
    couchbasebuild/docker-slave:20180323 \
    docker-slave-server \
    2995 server.jenkins.couchbase.com
