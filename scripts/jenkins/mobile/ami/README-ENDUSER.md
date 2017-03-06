
Running the Couchbase Mobile Sync Gateway / Sync Gateway Accelerator AMI

## AMI Overview

The following AMI's are available on the AWS Marketplace:

1. Sync Gateway 1.4 Community Edition
1. Sync Gateway 1.4 Enterprise Edition
1. Sync Gateway Accelerator 1.4 Enterprise Edition

## Launch Sync Gateway with in-memory database

The following instructions will work with both Sync Gateway and Sync Gateway Accelerator

* Choose AMI with the appropriate region
* Configure Instance Details / Advanced Details
* Paste the [sg_launch.py](https://raw.githubusercontent.com/couchbase/build/master/scripts/jenkins/mobile/ami/sg_launch.py) script contents into the text area in Advanced Details (the "as-text" radio button should be checked)
* Customize the content inside the triple quoted string with they Sync Gateway configuration you want to use: ```"""{"log":["HTTP+","Changes+",...] .. your config file contents goes here .. """```
* Since this uses the in-memory database (aka "Walrus"), leave the server setting as `"server":"walrus:data",` in the configuration
* Edit your Security Group to expose port 4984 to Anywhere
* Launch instance

### Verify

* In the AWS Management Console web UI, go to the **EC2** section and look for the instance you just launched, and click it to show the instance details
* Find the public dns name of the instance from the **Public DNS (IPv4)** field: it should look something like **ec2-54-152-154-24.compute-1.amazonaws.com**
* In your browser, go to **http://<public-dns-name-of-instance>:4984** and it should return JSON content like `{couchdb: "Welcome", ..etc ..`


## Launch Sync Gateway + Sync Gateway Accelerator + Couchbase Server








