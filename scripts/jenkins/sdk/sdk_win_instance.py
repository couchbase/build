#!/usr/bin/python
import sys
import boto3
import botocore
import datetime
import time

if len(sys.argv) != 3:
    print 'Usage: sdk_win_instance.py <instance-id> <start|stop>'
    sys.exit(1)

iid = sys.argv[1]
cmd = sys.argv[2]
wait_time = 360

client = boto3.client('ec2')
response = client.describe_instances(InstanceIds=[iid])

try:
    if cmd == 'start':
        state = response['Reservations'][0]['Instances'][0]['State']['Name']
        if state != 'running':
            client.start_instances(InstanceIds=[iid])
            time.sleep(wait_time)
    elif cmd == 'stop':
        client.stop_instances(InstanceIds=[iid])
        sys.exit(0)
    else:
        print 'Unknown command, %s' %cmd
        sys.exit(1)
except botocore.exceptions.ClientError, e:
    if e.message.find('InvalidInstanceID') > 0:
        print 'There is no such instance [%s] on AWS, perhaps we are given a wrong argument?' %iid
        sys.exit(1)

    print "Exception:", 
    print e
    sys.exit(2)

if cmd == 'start':
    response = client.describe_instances(InstanceIds=[iid])
    ip = response['Reservations'][0]['Instances'][0]['PublicIpAddress']
    print ip

sys.exit(0)
