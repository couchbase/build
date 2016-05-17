#!/bin/bash

docker stop mobile-light
docker rm -f mobile-light
docker run --name="mobile-light" -v /home/couchbase/jenkinsdocker-ssh:/ssh \
        --volume=/home/couchbase/latestbuilds:/latestbuilds \
        -p 2300:22 -d ceejatec/ubuntu1404-mobile-android-docker:20151001

docker stop mobile-android
docker rm -f mobile-android
docker run --name="mobile-android" -v /home/couchbase/jenkinsdocker-ssh:/ssh -p 2422:22 -d ceejatec/ubuntu1404-mobile-android-docker:20151001

docker stop mobile-java
docker rm -f mobile-java
docker run --name="mobile-java" -v /home/couchbase/jenkinsdocker-ssh:/ssh -p 2424:22 -d ceejatec/ubuntu1404-mobile-android-docker:20151001

