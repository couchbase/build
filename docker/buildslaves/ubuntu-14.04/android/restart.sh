#!/bin/bash

docker rm -f mobile-light
docker run --name="mobile-light" -v /home/couchbase/jenkinsdocker-ssh:/ssh \
        --volume=/home/couchbase/latestbuilds:/latestbuilds \
        --restart=unless-stopped \
        -p 2300:22 -d ceejatec/ubuntu1404-mobile-android-docker:20160712

docker rm -f mobile-android
docker run --name="mobile-android" -v /home/couchbase/jenkinsdocker-ssh:/ssh \
        --restart=unless-stopped \
        -p 2422:22 -d ceejatec/ubuntu1404-mobile-android-docker:20160712

docker rm -f mobile-java
docker run --name="mobile-java" -v /home/couchbase/jenkinsdocker-ssh:/ssh \
        --restart=unless-stopped \
        -p 2424:22 -d ceejatec/ubuntu1404-mobile-android-docker:20160712

