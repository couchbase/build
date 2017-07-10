#!/bin/bash

# These are currently all hosted on mega

echo @@@@@@@@@@@@@@@@@@@@@@
echo @ Recreating slaves
echo @@@@@@@@@@@@@@@@@@@@@@
../buildslaves/centos-65/sgw_jenkins/restart.sh
../buildslaves/centos-70/sgw_jenkins/restart.sh
../buildslaves/ubuntu-14.04/sgw_jenkins/restart.sh
../buildslaves/ubuntu-14.04/android/restart.sh
./restart_jenkinsdocker.py ceejatec/ubuntu-1604-couchbase-build:latest zz-mobile-lightweight 2423 mobile.jenkins.couchbase.com
./restart_jenkinsdocker.py ceejatec/centos-72-litecore-build:20170710 mobile-litecore-linux 6501 mobile.jenkins.couchbase.com

