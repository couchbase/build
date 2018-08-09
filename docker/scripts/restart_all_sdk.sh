#!/bin/sh

# These currently run on mega3
start_dock() {
    docker run \
        --name=$2 \
        --detach=true \
        --restart=unless-stopped \
        --publish=$3:22 \
        --volume=/etc/resolv.conf:/etc/resolv.conf \
        --volume=/etc/localtime:/etc/localtime \
        --volume=/etc/timezone:/etc/timezone \
        --volume=/home/couchbase/s3_cache:/home/couchbase/s3_cache \
        --volume=/home/couchbase/.s3cfg:/home/couchbase/.s3cfg \
        --volume=/home/couchbase/.aws:/home/couchbase/.aws \
        --volume=/home/couchbase/jenkinsdocker-ssh:/ssh \
        $1

    sleep 2
}

mkdir -p /home/couchbase/s3_cache
docker rm -f centos65-docker-01
start_dock couchbase/centos-69-sdk-nodevtoolset-build:20180809 centos65-docker-01 5555

docker rm -f ubuntu1404-docker-01
start_dock couchbase/ubuntu-1404-sdk-build:20180806 ubuntu1404-docker-01 5556

docker rm -f centos70-docker-01
start_dock couchbase/centos-70-sdk-build:20180808 centos70-docker-01 5557

docker rm -f zz-lightweight
start_dock couchbase/ubuntu-1404-sdk-build:20180806 zz-lightweight 5566

docker rm -f centos65-docker-devkit1.1-02
start_dock couchbase/centos-69-sdk-build:20180806 centos65-docker-devkit1.1-02 5558
