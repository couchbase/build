#!/bin/sh

# No longer using these - cv.jenkins uses Docker plugin to spin
# up instances on demand. The zz-lightweight one is still necessary.
./restart_swarmdocker.py cv ubuntu-1204 3224 http://172.23.113.52:8081 10 cv-zz-lightweight lightweight

