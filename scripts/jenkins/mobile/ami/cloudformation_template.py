
# Python script to generate an AWS CloudFormation template json file

import collections
from troposphere import Ref, Template, Parameter, Tags, Base64, Join, GetAtt, Output
import troposphere.autoscaling as autoscaling
from troposphere.elasticloadbalancing import LoadBalancer
from troposphere import GetAZs
import troposphere.ec2 as ec2
import troposphere.elasticloadbalancing as elb
from troposphere import iam
from troposphere.route53 import RecordSetType
import sgautoscale_cloudformation_template as sgautoscale

def gen_template(config):

    t = Template()
    t.add_description(
        'Sync Gateway + Sync Gateway Accelerator + Couchbase Server'
    )
    
    #
    # Template Parameters
    #
    keyname_param = t.add_parameter(Parameter(
        'KeyName',
        Type='String',
        Description='Name of an existing EC2 KeyPair to enable SSH access',
        MinLength=1,
    ))
    couchbase_server_instance_type_param = t.add_parameter(Parameter(
        'CouchbaseServerInstanceType',
        Type='String',
        Description='The InstanceType to use for Couchbase Server instance',
        Default='m3.medium',
    ))
    sync_gateway_instance_type_param = t.add_parameter(Parameter(
        'SyncGatewayInstanceType',
        Type='String',
        Description='The InstanceType to use for Sync Gateway instance',
        Default='m3.medium',
    ))
    sg_accel_instance_type_param = t.add_parameter(Parameter(
        'SgAccelInstanceType',
        Type='String',
        Description='The InstanceType to use for Sync Gateway Accel instance',
        Default='m3.medium',
    ))
    couchbase_server_admin_user_param = t.add_parameter(Parameter(
        'CouchbaseServerAdminUserParam',
        Type='String',
        Description='The Couchbase Server Admin username',
        Default='Administrator',
    ))
    couchbase_server_admin_pass_param = t.add_parameter(Parameter(
        'CouchbaseServerAdminPassParam',
        Type='String',
        Description='The Couchbase Server Admin password',
        MinLength=8,
        NoEcho=True,
    ))
    
    # Security Group
    # ------------------------------------------------------------------------------------------------------------------
    secGrpCouchbase = ec2.SecurityGroup('CouchbaseSecurityGroup')
    secGrpCouchbase.GroupDescription = "External Access to Sync Gateway user port"
    t.add_resource(secGrpCouchbase)

    # Ingress: Public
    # ------------------------------------------------------------------------------------------------------------------
    t.add_resource(ec2.SecurityGroupIngress(
        'IngressSSH',
        GroupName=Ref(secGrpCouchbase),
        IpProtocol="tcp",
        FromPort="22",
        ToPort="22",
        CidrIp="0.0.0.0/0",
    ))
    t.add_resource(ec2.SecurityGroupIngress(
        'IngressSyncGatewayUser',
        GroupName=Ref(secGrpCouchbase),
        IpProtocol="tcp",
        FromPort="4984",
        ToPort="4984",
        CidrIp="0.0.0.0/0",
    ))

    # Ingress: within Security Group
    # ------------------------------------------------------------------------------------------------------------------
    t.add_resource(
        tcpIngressWithinGroup(
            name='IngressCouchbaseErlangPortMapper',
            port="4369",
            group=secGrpCouchbase,
            groupname="CouchbaseSecurityGroup",
        )
    )
    t.add_resource(
        tcpIngressWithinGroup(
            name='IngressSyncGatewayAdmin',
            port="4985",
            group=secGrpCouchbase,
            groupname="CouchbaseSecurityGroup",
        )
    )
    t.add_resource(
        tcpIngressWithinGroup(
            name='IngressCouchbaseWebAdmin',
            port="8091",
            group=secGrpCouchbase,
            groupname="CouchbaseSecurityGroup",
        )
    )
    t.add_resource(
        tcpIngressWithinGroup(
            name='IngressCouchbaseAPI',
            port="8092",
            group=secGrpCouchbase,
            groupname="CouchbaseSecurityGroup",
        )
    )
    t.add_resource(
        tcpIngressWithinGroup(
            name='IngressCouchbaseInternalBucketPort',
            port="11209",
            group=secGrpCouchbase,
            groupname="CouchbaseSecurityGroup",
        )
    )
    t.add_resource(
        tcpIngressWithinGroup(
            name='IngressCouchbaseInternalExternalBucketPort',
            port="11210",
            group=secGrpCouchbase,
            groupname="CouchbaseSecurityGroup",
        )
    )
    t.add_resource(
        tcpIngressWithinGroup(
            name='IngressCouchbaseClientInterfaceProxy',
            port="11211",
            group=secGrpCouchbase,
            groupname="CouchbaseSecurityGroup",
        )
    )
    t.add_resource(
        ec2.SecurityGroupIngress(
            'IngressCouchbaseNodeDataExchange',
            GroupName=Ref(secGrpCouchbase),
            IpProtocol="tcp",
            FromPort="21100",
            ToPort="21299",
            SourceSecurityGroupId=GetAtt("CouchbaseSecurityGroup", "GroupId"),
        )
    )


    # Couchbase Server Instance
    # ------------------------------------------------------------------------------------------------------------------
    name = "couchbaseserver"
    instance = ec2.Instance(name)
    instance.ImageId = config.couchbase_ami_id
    instance.InstanceType = Ref(couchbase_server_instance_type_param)
    instance.SecurityGroups = [Ref(secGrpCouchbase)]
    instance.KeyName = Ref(keyname_param)
    instance.Tags = Tags(Name=name, Type="couchbaseserver")
    instance.UserData = sgautoscale.userDataCouchbaseServer(
        config.build_repo_commit,
        config.sgautoscale_repo_commit,
        Ref(couchbase_server_admin_user_param),
        Ref(couchbase_server_admin_pass_param),
    )
    instance.BlockDeviceMappings=[sgautoscale.blockDeviceMapping(config, "couchbaseserver")]
    t.add_resource(instance)

    # Sync Gateway Instance
    # ------------------------------------------------------------------------------------------------------------------
    name = "syncgateway"
    instance = ec2.Instance(name)
    instance.ImageId = config.sync_gateway_ami_id
    instance.InstanceType = Ref(sync_gateway_instance_type_param)
    instance.SecurityGroups = [Ref(secGrpCouchbase)]
    instance.KeyName = Ref(keyname_param)
    instance.Tags = Tags(Name=name, Type="syncgateway")
    instance.UserData = sgautoscale.userDataSyncGatewayOrAccel(
        config.build_repo_commit,
        config.sgautoscale_repo_commit,
    )
    instance.BlockDeviceMappings=[sgautoscale.blockDeviceMapping(config, "syncgateway")]
    t.add_resource(instance)
    
    # SG Accel Instance
    # ------------------------------------------------------------------------------------------------------------------
    name = "sgaccel"
    instance = ec2.Instance(name)
    instance.ImageId = config.sg_accel_ami_id
    instance.InstanceType = Ref(sg_accel_instance_type_param)
    instance.SecurityGroups = [Ref(secGrpCouchbase)]
    instance.KeyName = Ref(keyname_param)
    instance.Tags = Tags(Name=name, Type="sgaccel")
    instance.UserData = sgautoscale.userDataSyncGatewayOrAccel(
        config.build_repo_commit,
        config.sgautoscale_repo_commit,
    )
    instance.BlockDeviceMappings=[sgautoscale.blockDeviceMapping(config, "sgaccel")]
    t.add_resource(instance)


    return t.to_json()


def tcpIngressWithinGroup(name, port, group, groupname):
    return ec2.SecurityGroupIngress(
        name,
        GroupName=Ref(group),
        IpProtocol="tcp",
        FromPort=port,
        ToPort=port,
        SourceSecurityGroupId=GetAtt(groupname, "GroupId"),
    )


# Main
# ----------------------------------------------------------------------------------------------------------------------
def main():

    Config = collections.namedtuple(
        'Config',
        " ".join([
            'couchbase_ami_id',
            'sync_gateway_ami_id',
            'sg_accel_ami_id',
            'block_device_name',
            'block_device_volume_size_by_server_type',
            'block_device_volume_type',
            'build_repo_commit',
            'sgautoscale_repo_commit',
        ]),
    )

    region = "us-east-1"  # TODO: make cli parameter

    # Generated via http://uberjenkins.sc.couchbase.com/view/Build/job/couchbase-server-ami/
    couchbase_ami_ids_per_region = {
        "us-east-1": "ami-907dda86",
        "us-west-1": "ami-d45c05b4"
    }

    # Generated via http://uberjenkins.sc.couchbase.com/view/Build/job/sync-gateway-ami/
    sync_gateway_ami_ids_per_region = {
        "us-east-1": "ami-ff9842e9",
        "us-west-1": "ami-4cf0ae2c"
    }

    # Generated via http://uberjenkins.sc.couchbase.com/view/Build/job/sg-accel-ami/
    sg_accel_ami_ids_per_region = {
        "us-east-1": "ami-cc8027da",
        "us-west-1": "ami-9a267ffa"
    }

    config = Config(
        couchbase_ami_id=couchbase_ami_ids_per_region[region],
        sync_gateway_ami_id=sync_gateway_ami_ids_per_region[region],
        sg_accel_ami_id=sg_accel_ami_ids_per_region[region],
        block_device_name="/dev/xvda",  # "/dev/sda1" for centos, /dev/xvda for amazon linux ami
        block_device_volume_size_by_server_type={"couchbaseserver": 200, "syncgateway": 25, "sgaccel": 25},
        block_device_volume_type="gp2",
        build_repo_commit="master",
        sgautoscale_repo_commit="master",
    )

    templ_json = gen_template(config)

    template_file_name = "generated_cloudformation_template.json"
    with open(template_file_name, 'w') as f:
        f.write(templ_json)

    print("Wrote cloudformation template: {}".format(template_file_name))


if __name__ == "__main__":
    main()
