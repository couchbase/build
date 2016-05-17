#!/bin/bash

# Script intended to be ENTRYPOINT for Couchbase build containers

# First, copy any files in /ssh to /home/couchbase/.ssh, changing ownership to
# user couchbase and maintaining permissions
if [ -d /ssh ] && [ "$(ls -A /ssh)" ]
then
    cp -a /ssh/* /home/couchbase/.ssh
fi
chown -R couchbase:couchbase /home/couchbase/.ssh
chmod 600 /home/couchbase/.ssh/*

# Start sshd (as new, long-running, foreground process)
[[ "$1" == "default" ]] && {
    exec /usr/sbin/sshd -D
}

exec "$@"

