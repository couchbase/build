
Running the Couchbase Mobile AMI

## Overview

The Couchbase Mobile AMI has the following components included:

* Couchbase Server (single-node)
* Sync Gateway

## Quickstart

* Choose AMI with the appropriate region
* Click the "Launch with EC2 console" button
* Configure Instance Details / Advanced Details
* Paste the [user-data.sh](https://raw.githubusercontent.com/couchbase/build/master/scripts/jenkins/mobile/ami/user-data.sh) script contents into the text area in Advanced Details
* If you want to run a custom Sync Gateway configuration, you should customize the variables in the Customization section of the user-data.sh script you just pasted.  You can set the Sync Gateway config to any public URL and will need to update the Couchbase Server bucket name to match what's in your config.
* Edit your Security Group to expose port 4984 to Anywhere

## Verify

* Find the Public DNS entry of the instance you just launched
* Open `http://<public-ip-of-instance>:4984` in your web browser
* You should get a 200 OK response with JSON content that has the Sync Gateway version

## Explore Couchbase Server

* In the AWS console, find the instance-id of the running instance (eg, i-56b1accd)
* Edit the Security Group for the running instance to enable access to port `8091`
* Open `http://<public-ip-of-instance>:8091` in your web browser
* Login with **Administrator**/**[ec2 instance-id]**

## Explore Sync Gateway

* See the [Sync Gateway REST API docs](http://developer.couchbase.com/documentation/mobile/1.2/develop/references/sync-gateway/index.html) for more information on using Sync Gateway
* Install a [Sample App](http://developer.couchbase.com/documentation/mobile/current/develop/samples/samples/index.html) and set it up to Sync it's data with Sync Gateway
