#!/usr/bin/python
import sys
import boto3
import botocore
import datetime
import time
import json

def check(inst, num_hours, itype):
    state = inst['State']['Name']
    if state.lower() == 'stopped' or \
       state.lower() == 'stopped' or \
       state.lower() == 'shutting-down' or \
       state.lower() == 'terminated':
        print 'Instance is not running'
        return 0

    launch_time = inst['LaunchTime']
    launch_time_int = int(time.mktime(launch_time.timetuple()))
    utc_now_int = int(time.mktime(datetime.datetime.utcnow().timetuple()))
    up_since = (utc_now_int - launch_time_int) / 3600 + 1
    print 'The %s instance %s has been running for %d hours.' %(itype, inst['InstanceId'], up_since)
    if up_since > num_hours:
        print 'The SDK build/test instance %s on AWS has been' %(inst['InstanceId'])
        print 'running for more than %d hours. Please shut it down' %num_hours
        return 1


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

processed = []
responses = client.describe_instances()
for resp in responses:
    for reserv in responses['Reservations']:
        for inst in reserv['Instances']:
            if inst['InstanceId'] in processed:
                continue
            tags = inst['Tags']
            gotinstance = 0
            for t in tags:
                if t['Key'] == 'Name':
                    if t['Value'] == iname:
                        if inst['InstanceId'] == iid:
                            if check(inst, int(num_hours), 'build'):
                                gotinstance = 1
                # on my last week, due to lack of time, also hacking to monitor sdk test instances
                # doesn't really make sense to take iid parameter for the build instance
                # but also blindly check for instances; but...
                if t['Key'] == 'use':
                    if t['Value'].find('-sdk') != -1:
                        if check(inst, int(num_hours), 'test'):
                            gotinstance = 1
            processed.append(inst['InstanceId'])

sys.exit(gotinstance)
