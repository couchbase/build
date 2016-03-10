#!/bin/bash

# These are currently all hosted on mega

echo @@@@@@@@@@@@@@@@@@@@@@
echo @ Recreating slaves
echo @@@@@@@@@@@@@@@@@@@@@@
../buildslaves/centos-65/sgw_jenkins/restart.sh
../buildslaves/ubuntu-14.04/sgw_jenkins/restart.sh
../buildslaves/ubuntu-14.04/android/restart.sh
./restart_jenkinsdocker.py ceejatec/ubuntu-1204-couchbase-build:latest zz-mobile-lightweight 2423 mobile.jenkins.couchbase.com

