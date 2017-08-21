#!/bin/bash

# Script intended to be ENTRYPOINT for buildboard containers

# First, copy any files in /ssh to /root/.ssh, ensure ownership is
# the root user and maintain permissions
if [ -d /ssh ] && [ "$(ls -A /ssh)" ]
then
    cp -a /ssh/* /root/.ssh
fi
chown -R root:root /root/.ssh
chmod 600 /root/.ssh/*

/usr/sbin/httpd &

cd /home/couchbase/buildboard
./runapps.py > /var/log/bbapps.log 2>&1 &
./buildboard.py > /var/log/bbconsole.log 2>&1
