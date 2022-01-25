#!/bin/bash

### This script is intended for kicking of sanity test suits against amzn aarch64 environments.
### It should be launched from an AWS x86_64 instance as some of the python packages required by
### testrunner only work on x86_64.
###
### Internal IPs are used for communications by test cases, hence it is desired to run this script
### from an AWS instance where nodes/clusters can be reached via internal IPs.
###
### It performs the following tasks:
### 1. Install required packages for testrunner
### 1. Download rpm from nas
### 2. Prepare AWS environment, including placement group, security group, ec2 instances
### 3. Install rpm on created instances
### 4. Run testrunner against the ec2 instances
### 5. Delete ec2, security group, and placement group.

### Fixed Variables
### AWS account used for sanity test is cb-build
### AWS_AMI:        amzn ami
### VPC_ID:         Reuse jenkins-workers vpc, since it is already been used by server/cv jenkins
### AWS_PROFILE:    access key and region are defined in profile so that aws command knows where
###                 to launch/access to ec2 instances
### SUBNET_ID:      subnet-019c2d8fb47a70cdd is a public subnet under the vpc.
### INTERNAL_CDIR:  Internal IPs to be whitelisted so that the nodes within the cluser can
###                 communicate with each other
###                 TODO: get public subnet via query

### Environment Variables that needs to be set before running this script
### NAS_UID: uid to access nas.service.couchbase.com
### NAS_PW:  password to NAS_UID
### AWS_ACCESS_KEY_ID: AWS key id.  The key needs to be able to create/delete placement group, security group, and EC2
### AWS_SECRET_ACCESS_KEY: AWS access key

AWS_AMI="ami-0806cc3ac66515671"
VPC_ID="vpc-00291041ad30ebce5"
AWS_PROFILE="cb-build"
REGION="us-east-2"
SUBNET_ID="subnet-0040bcb6e1894c053"
INTERNAL_CIDR="10.0.0.0/16"
EC2_TYPE="c6g.xlarge"
KEYPAIR_NAME="jenkins-workers"

prep_env() {
  # Install required tools for testrunner
  # Newer couchbase-release doesn't seem to work for testrunner.  Pin to couchbase-release-1.0-6 for now
  curl --fail -LO  http://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-6-x86_64.rpm || { echo "Unable to download couchbase-release-1.0-6-x86_64.rpm"; exit;}
  sudo yum install -y couchbase-release-1.0-6-x86_64.rpm

  curl --fail -LO http://${NAS_UID}:${NAS_PW}@nas.service.couchbase.com/builds/latestbuilds/couchbase-server/zz-versions/${VERSION}/${CURRENT_BUILD_NUMBER}/couchbase-server-enterprise-${VERSION}-${CURRENT_BUILD_NUMBER}-amzn2.x86_64.rpm || { echo "Unable to download couchbase-server-enterprise-${VERSION}-${CURRENT_BUILD_NUMBER}-amzn2.x86_64.rpm from nas"; exit;}
  mkdir -p ~/opt
  sudo yum install -y ./couchbase-server-enterprise-${VERSION}-${CURRENT_BUILD_NUMBER}-amzn2.x86_64.rpm
  ln -s /opt/couchbase ~/opt/couchbase

  sudo yum install -y libcouchbase-devel libcouchbase2-bin libcouchbase2-libevent gcc gcc-c++
  sudo yum install -y python3-devel python3-pip jq
  yes | pip3 install git+git://github.com/couchbase/couchbase-python-client.git@2.5.11
  yes | pip3 install sgmllib3k paramiko httplib2 pyyaml beautifulsoup4 Geohash python-geohash deepdiff pyes pytz requests jsonpickle docker decorator boto3
  yes | pip3 install google-cloud-storage
  export PATH=/home/ec2-user/.local/bin:$PATH

  mkdir ~/.aws
  echo "[${AWS_PROFILE}]" > ~/.aws/credentials
  echo "aws_access_key_id = ${AWS_ACCESS_KEY_ID}" >> ~/.aws/credentials
  echo "aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}" >> ~/.aws/credentials

  echo "[profile ${AWS_PROFILE}]" > ~/.aws/config
  echo "region=${REGION}" >> ~/.aws/config
  echo "output=json" ~/.aws/config

  echo "Host *
  StrictHostKeyChecking no" >> ~/.ssh/config
  chmod 400 ~/.ssh/config
}

create_pg() {
  # Create placement group
  result=`aws ec2 describe-placement-groups \
              --group-name ${PG_NAME} \
              --region ${REGION}`
  echo $result
  if [[ ${result} == *"${PG_NAME}"* ]]; then
    echo "${PG_NAME} already exist.  No need to recreate it."
  else
    aws ec2 create-placement-group \
        --group-name ${PG_NAME} \
        --strategy cluster \
        --profile ${AWS_PROFILE} \
        --region ${REGION}
  fi
}
create_sg() {
  # Create security group if it doesn't exist
  # Whitelist internal IPs once the group is created.
  result=`aws ec2 describe-security-groups \
              --profile ${AWS_PROFILE} \
              --filters Name=vpc-id,Values=${VPC_ID} Name=group-name,Values=${SG_NAME}`
  echo $result
  if [[ ${result} == *"${SG_NAME}"* ]]; then
    echo "${SG_NAME} already exist.  No need to recreate it."
    SG_ID=`echo ${result} |jq -r '.SecurityGroups[].GroupId'`
    echo ${SG_ID}
  else
    result=`aws ec2 create-security-group \
                --group-name ${SG_NAME} \
                --description "Sanity Test Security Group" \
                --vpc-id ${VPC_ID} \
                --profile ${AWS_PROFILE}`
    SG_ID=`echo ${result} | jq -r '.GroupId'`
    echo ${SG_ID}
    update_sg "${INTERNAL_CIDR}"
  fi
}

update_sg() {
  local cidr_range=$1
  result=`aws ec2 describe-security-groups \
              --profile ${AWS_PROFILE} \
              --filters Name=vpc-id,Values=${VPC_ID} Name=group-name,Values=${SG_NAME}`
  echo $result
  if [[ $result == *"$cidr_range"* ]]; then
    echo "$cidr_range is in ${SG_NAME} already."
  else
    aws ec2 authorize-security-group-ingress \
      --profile ${AWS_PROFILE} \
      --group-id ${SG_ID}\
      --protocol all \
      --cidr $cidr_range
  fi
}

create_ec2() {
  local ec2_count=$1
  result=`aws ec2 run-instances \
              --image-id ${AWS_AMI} \
              --instance-type ${EC2_TYPE} \
              --placement "GroupName=${PG_NAME}" \
              --key-name "${KEYPAIR_NAME}" \
              --security-group-ids "${SG_ID}" \
              --subnet-id "${SUBNET_ID}" \
              --tag-specifications "ResourceType=instance,Tags=[{Key=Owner,Value=QE}}, {Key=placement,Value=${PG_NAME}},{Key=Name,Value=sanity_test${PG_NAME}}]" \
              --instance-initiated-shutdown-behavior terminate \
              --count $ec2_count \
              --profile "${AWS_PROFILE}"`

  echo $result > out.json
  if [ -z "$result" ]; then
    echo "Unable to create instance(s).  Please check log output."
    exit 1
  fi
  INSTANCE_IDS=`echo $result |jq -r '.Instances[].InstanceId'`

  ### Wait for ec2 to come up
  x=1
  while [ $x -le 10 ]
  do
    INSTANCE_STATE=`aws ec2 describe-instance-status --instance-ids ${INSTANCE_IDS} --profile ${AWS_PROFILE} | jq -r '.InstanceStatuses[].InstanceState.Name' |uniq`
    x=$(( $x + 1 ))
    if [ "${INSTANCE_STATE}" == "running" ]; then
      break
    fi
    echo "Waiting for EC2 instance(s) to come up..."
    sleep 30
  done

  INSTANCE_DNS_NAMES=`aws ec2 describe-instances --instance-ids ${INSTANCE_IDS} --query "Reservations[*].Instances[*].PublicDnsName" --profile ${AWS_PROFILE} |jq -r ".[][]"`
  echo ${INSTANCE_DNS_NAMES}
  INSTANCE_IPS=`aws ec2 describe-instances --instance-ids ${INSTANCE_IDS} --query "Reservations[*].Instances[*].PrivateIpAddress" --profile ${AWS_PROFILE} |jq -r ".[][]"`
  echo ${INSTANCE_IPS}
}

teardown() {
  echo "Terminating ec2 instance(s)..."
  aws ec2 terminate-instances \
      --instance-ids ${INSTANCE_IDS} \
      --profile ${AWS_PROFILE}
  ##ensure ec2 instances are in terminated state before deleting security group
  sleep 60
  echo "Deleting security group..."
  aws ec2 delete-security-group \
      --group-id ${SG_ID} \
      --profile ${AWS_PROFILE}
  echo "Deleting placement group..."
  aws ec2 delete-placement-group \
      --group-name ${PG_NAME} \
      --region ${REGION}
}
usage() {
  echo "USAGE:"
  echo "$0 -p <placement group name>  -s <security group name> -n <number of nodes> -k <sshkey path> -b <build number> -v <version>"
  echo "where:"
  echo "  -p: aws placement group name, i.e. sanity_test"
  echo "  -s: aws security group name, i.e. sanity_test"
  echo "  -t: sanity test type, 1node, 4node_1, or 4node_2"
  echo "  -k: full path of sshkey for ec2"
  echo "  -b: build number, i.e. 1180"
  echo "  -v: versoin, i.e. 7.1.0"
  echo
}
while getopts "p:s:t:k:b:v:h" opt; do
  case $opt in
    p) PG_NAME=$OPTARG;;
    s) SG_NAME=$OPTARG;;
    t) TYPE=$OPTARG;;
    k) SSHKEY=$OPTARG;;
    b) BLD_NUM=$OPTARG;;
    v) VERSION=$OPTARG;;
    h|?) usage
      exit 0;;
    *) echo "Invalid argument $opt"
      usage
      exit 1;;
  esac
done

if [[ -z ${PG_NAME} || -z ${SG_NAME} || -z ${TYPE} || -z ${SSHKEY} || -z ${BLD_NUM} || -z ${VERSION} ]]; then
  usage
  exit 1
fi

NUM_NODE=`echo ${TYPE} |awk -F 'node' '{print $1}'`
if [[ -z ${NUM_NODE} ]]; then
  echo 'Unable to identify number of nodes from ${TYPE} input.  Please check your command.'
  usage
  exit 1
fi

if [[ `uname -r` != *"amzn2.x86_64"* ]]; then
  echo "This script must be run from an amzn2 x86_64 instance.\n"
  usage
  exit 1
fi
### Get IP of current host so that it can be whitelisted for ec2 communication
REMOTE_HOST_PUBLIC_IP=`curl http://checkip.amazonaws.com`

prep_env
create_pg
create_sg
create_ec2 ${NUM_NODE}

trap teardown EXIT

PKG_NAME=couchbase-server-enterprise-${VERSION}-${BLD_NUM}-amzn2.aarch64.rpm
curl --fail -LO http://${NAS_UID}:${NAS_PW}@nas.service.couchbase.com/builds/latestbuilds/couchbase-server/zz-versions/${VERSION}/${BLD_NUM}/${PKG_NAME} || { echo "Unable to download ${PKG_NAME} from nas"; exit;}

for ip in ${INSTANCE_IPS}; do
  scp -i ${SSHKEY} ${PKG_NAME} ec2-user@$ip:/tmp/.
  ssh -i ${SSHKEY} ec2-user@$ip "sudo yum install -y /tmp/${PKG_NAME}"

  ###Instances might be left running when jenkins job is aborted.
  ###This ensure the instances are terminated.
  ###Instances are provisioned to be terminated when shutdown.
  ssh -i ${SSHKEY} ec2-user@$ip "sudo shutdown -P +180"

  ssh -i ${SSHKEY} ec2-user@$ip 'sudo bash -c "cp -rp /home/ec2-user/.ssh /root/.; chown -R root:root /root/.ssh"'

done

nodes=(${INSTANCE_IPS})

echo "[global]
username:root
ssh_key:${SSHKEY}
port:8091
n1ql_port:8093
index_port:9102

[membase]
rest_username:Administrator
rest_password:password

[_1]
ip:${nodes[0]}
services:kv,index,n1ql,backup,fts
" > node_conf.ini

case $NUM_NODE in
  1)
    TR_CONF="conf/py-1node-sanity.conf"
    if [[ "$EXTRA_TEST_PARAMS" == *"bucket_storage=magma"* ]]; then
        TR_CONF="conf/magma-py-1node-sanity.conf"
    fi
    echo "[servers]
1:_1" >> node_conf.ini
    ;;
  4)
    conf_type=`echo ${TYPE} |awk -F 'node_' '{print $2}'`
    TR_CONF="conf/py-multi-node-sanity-$conf_type.conf"
    if [[ "$EXTRA_TEST_PARAMS" == *"bucket_storage=magma"* ]]; then
        TR_CONF="conf/magma-py-multi-node-sanity-$conf_type.conf"
    fi
    echo "[cluster1]
1:_1
2:_2

[cluster2]
1:_3
2:_4

[servers]
1:_1
2:_2
3:_3
4:_4

[_2]
ip:${nodes[1]}
port:8091

[_3]
ip:${nodes[2]}
services:kv,index,n1ql,backup,fts
port:8091

[_4]
ip:${nodes[3]}
services:kv,cbas
port:8091" >> node_conf.ini
    ;;
  *)
    echo -n "unknown"
    ;;
esac

#${EXTRA_INSTALL_PARAMS} and ${EXTRA_TEST_PARAMS} could be passed in from jenkins job
PARAMS="version=${VERSION}-${BLD_NUMBER},product=cb,parallel=True,install_tasks=init,${EXTRA_INSTALL_PARAMS}"
COUCHBASE_NUM_VBUCKETS=64  python3 scripts/new_install.py -i node_conf.ini -p $PARAMS

python3 testrunner.py -i node_conf.ini -c ${TR_CONF} -p get-cbcollect-info=True,get-couch-dbinfo=True,skip_cleanup=False,skip_log_scan=False,skip_security_scan=False${EXTRA_TEST_PARAMS}
