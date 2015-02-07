#!/bin/bash

docker rm -f mobile-android
docker run --name="mobile-android" -v /home/couchbase/jenkinsdocker-ssh:/ssh -p 2422:22 -d ceejatec/ubuntu1404-mobile-android-docker:3a1d2.feb04

