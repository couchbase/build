#!/bin/bash

docker run --name="centos-x64-sgw" -v /home/couchbase/jenkinsdocker-ssh:/ssh -p 2423:22 -d ceejatec/centos-65-sgw-build
