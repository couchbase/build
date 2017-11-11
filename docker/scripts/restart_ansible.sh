#!/bin/bash

./restart_jenkinsdocker.py couchbasebuild/ansible-slave:20171110 ansible-slave-server 2999 server.jenkins.couchbase.com
./restart_jenkinsdocker.py couchbasebuild/ansible-slave:20171110 ansible-slave-mobile 2998 mobile.jenkins.couchbase.com

