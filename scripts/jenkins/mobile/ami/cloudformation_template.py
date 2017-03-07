
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
        'KeyName', Type='String',
        Description='Name of an existing EC2 KeyPair to enable SSH access'
    ))
    couchbase_server_instance_type_param = t.add_parameter(Parameter(
        'CouchbaseServerInstanceType', Type='String',
        Description='The InstanceType to use for Couchbase Server instance'
    ))
    sync_gateway_instance_type_param = t.add_parameter(Parameter(
        'SyncGatewayInstanceType', Type='String',
        Description='The InstanceType to use for Sync Gateway instance'
    ))
    sg_accel_instance_type_param = t.add_parameter(Parameter(
        'SgAccelInstanceType', Type='String',
        Description='The InstanceType to use for Sync Gateway Accel instance'
    ))
    couchbase_server_admin_user_param = t.add_parameter(Parameter(
        'CouchbaseServerAdminUserParam', Type='String',
        Description='The Couchbase Server Admin username'
    ))
    couchbase_server_admin_pass_param = t.add_parameter(Parameter(
        'CouchbaseServerAdminPassParam', Type='String',
        Description='The Couchbase Server Admin password'
    ))
    
    # Security Group + Launch Keypair
    # ------------------------------------------------------------------------------------------------------------------


    # Couchbase security group
    secGrpCouchbase = ec2.SecurityGroup('CouchbaseSecurityGroup')
    secGrpCouchbase.GroupDescription = "Allow access to Couchbase Server"

    # Add security group to template
    t.add_resource(secGrpCouchbase)

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

    t.add_resource(ec2.SecurityGroupIngress(
        'IngressSyncGatewayAdmin',
        GroupName=Ref(secGrpCouchbase),
        IpProtocol="tcp",
        FromPort="4985",
        ToPort="4985",
        SourceSecurityGroupId=GetAtt("CouchbaseSecurityGroup", "GroupId"),
    ))




    # secGrpCouchbase.SecurityGroupIngress = [
    #     ec2.SecurityGroupRule(
    #         IpProtocol="tcp",
    #         FromPort="22",
    #         ToPort="22",
    #         CidrIp="0.0.0.0/0",
    #     ),
    #     ec2.SecurityGroupRule(
    #         IpProtocol="tcp",
    #         FromPort="8091",
    #         ToPort="8091",
    #         CidrIp="0.0.0.0/0",
    #     ),
    #     ec2.SecurityGroupRule(   # sync gw user port
    #         IpProtocol="tcp",
    #         FromPort="4984",
    #         ToPort="4984",
    #         CidrIp="0.0.0.0/0",
    #     ),
    #
    #
    #     ec2.SecurityGroupRule(  # sync gw user port
    #         IpProtocol="tcp",
    #         FromPort="4985",
    #         ToPort="4985",
    #         # SourceSecurityGroupId=GetAtt(secGrpCouchbase, "GroupId"),
    #         SourceSecurityGroupId=GetAtt("CouchbaseSecurityGroup", "GroupId"),
    #     ),
    #     ec2.SecurityGroupRule(   # expvars
    #         IpProtocol="tcp",
    #         FromPort="9876",
    #         ToPort="9876",
    #         CidrIp="0.0.0.0/0",
    #     ),
    #     ec2.SecurityGroupRule(   # couchbase server
    #         IpProtocol="tcp",
    #         FromPort="4369",
    #         ToPort="4369",
    #         CidrIp="0.0.0.0/0",
    #     ),
    #     ec2.SecurityGroupRule(   # couchbase server
    #         IpProtocol="tcp",
    #         FromPort="5984",
    #         ToPort="5984",
    #         CidrIp="0.0.0.0/0",
    #     ),
    #     ec2.SecurityGroupRule(   # couchbase server
    #         IpProtocol="tcp",
    #         FromPort="8092",
    #         ToPort="8092",
    #         CidrIp="0.0.0.0/0",
    #     ),
    #     ec2.SecurityGroupRule(   # couchbase server
    #         IpProtocol="tcp",
    #         FromPort="11209",
    #         ToPort="11209",
    #         CidrIp="0.0.0.0/0",
    #     ),
    #     ec2.SecurityGroupRule(   # couchbase server
    #         IpProtocol="tcp",
    #         FromPort="11210",
    #         ToPort="11210",
    #         CidrIp="0.0.0.0/0",
    #     ),
    #     ec2.SecurityGroupRule(   # couchbase server
    #         IpProtocol="tcp",
    #         FromPort="11211",
    #         ToPort="11211",
    #         CidrIp="0.0.0.0/0",
    #     ),
    #     ec2.SecurityGroupRule(   # couchbase server
    #         IpProtocol="tcp",
    #         FromPort="21100",
    #         ToPort="21299",
    #         CidrIp="0.0.0.0/0",
    #     )
    #
    # ]






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
