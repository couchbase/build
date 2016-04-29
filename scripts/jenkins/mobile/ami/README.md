
## Build AMI

Use [this Jenkins job](http://uberjenkins.sc.couchbase.com:8080/view/Build/job/sync-gateway-ami/) (Couchbase Internal VPN only) to build the AMI.

If you go to the console logs, you can see the AMI ID's that have been created and pushed to AWS (cb-mobile account)

## Launch AMI

* Find the AMI for the appropriate region from the Jenkins Job
* Go to AWS console / EC2 / AMI
* Select AMI and launch
  * You will need to provide the user-data.sh script (or upload it directly) when launching the AMI.
  * You will need to open up port 4984 to access Sync Gateway

See README-ENDUSER.md for instructions

## Debugging AMI

Get the public ip of the AMI from the AWS web console, and then SSH into it via:

```
ssh ec2-user@<public-ip>
```

After it's launched, you can verify that the `user-data` script ran by running:

```
cat /var/log/cloud-init-output.log
```



