#!/usr/bin/python
import sys
import socket
import time
import datetime
import boto3
import botocore
from optparse import OptionParser

ami_id = 'ami-9e06d0fe'
sg_id = ['sg-8cd93bf5']
inst_type = 'c4.xlarge'
num_instances = 4

boto_ec2_obj = boto3.resource('ec2')
instances = boto_ec2_obj.create_instances(
                ImageId = ami_id,
                MinCount = num_instances,
                MaxCount = num_instances,
                SecurityGroupIds = sg_id,
                InstanceType = inst_type)

for inst in instances:
    inst.wait_until_running()
    inst.reload()

time.sleep(180)

pub_dns = []
pub_ips = []
priv_ips = []
for inst in instances:
    inst.reload()
    pub_ips.append(inst.public_ip_address)
    pub_dns.append(inst.public_dns_name)
    priv_ips.append(inst.private_ip_address)

with open('ec2.ips', 'w') as F:
    print >>F, 'PUB_DNS=' + ' '.join(pub_dns)
    print >>F, 'NODE_IPS=' + ' '.join(pub_ips)
    print >>F, 'PRIV_IPS=' + ' '.join(priv_ips)
    print >>F, 'SERVER_PUB_IP0=' + pub_ips[0]
    print >>F, 'SERVER_PRIV_IP0=' + priv_ips[0]
