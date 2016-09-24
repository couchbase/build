#!/usr/bin/python
import sys
import boto3
import botocore
import datetime
import time

if len(sys.argv) < 3:
    print 'The script takes at least 2 arguments'
    print
    print 'Usage: %s <instance_id> <instance_name> [number of hours]'
    print 'where:'
    print '    instance_id   -- instance id to monitor. It should have the name/tag windows-sdkbb'
    print '    instance_name -- the instance should be tagged with this name'
    print '    num_hours     -- if the instance has been up for more than this number of hours'
    print '                     the script will flag it. Default 24'
    sys.exit(1)

iid = sys.argv[1]
iname = sys.argv[2]
num_hours = 24
if len(sys.argv) > 3:
    num_hours = sys.argv[3]

client = boto3.client('ec2')

try:
    response = client.describe_instances(InstanceIds=[iid])
except botocore.exceptions.ClientError, e:
    if e.message.find('InvalidInstanceID') > 0:
        print 'There is no such instance [%s] on AWS, perhaps we are given a wrong argument?' %iid
        sys.exit(1)
    sys.exit(0)

tags = response['Reservations'][0]['Instances'][0]['Tags']
gotinstance = False
for t in tags:
    if t['Key'] == 'Name':
        if t['Value'] == iname:
            gotinstance = True

if not gotinstance:
    print 'The given instance id %s is not not windows sdk builds instance (it is not named "%s")' %(iid, iname)
    sys.exit(1)


state = response['Reservations'][0]['Instances'][0]['State']['Name']
if state.lower() == 'stopped' or \
   state.lower() == 'stopped' or \
   state.lower() == 'shutting-down' or \
   state.lower() == 'terminated':
    print 'Instance is not running'
    sys.exit(0)


launch_time = response['Reservations'][0]['Instances'][0]['LaunchTime']
launch_time_int = int(time.mktime(launch_time.timetuple()))
utc_now_int = int(time.mktime(datetime.datetime.utcnow().timetuple()))
up_since = (utc_now_int - launch_time_int) / 3600
print 'The instance has been running for %d hours.' %up_since
if up_since > num_hours:
    print 'The Windows SDK build instance %s on AWS has been' %iid
    print 'running for more than a day. Please shut it down'
    sys.exit(1)
