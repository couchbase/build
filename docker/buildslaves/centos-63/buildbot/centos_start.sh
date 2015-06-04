#!/bin/sh

ulimit -u 555555
gosu buildbot buildslave start /home/buildbot/buildbot_slave
exec /usr/sbin/sshd -D

