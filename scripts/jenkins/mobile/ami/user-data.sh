#!/bin/bash

set -x

# --------------- Customization Settings/Variables ---------------------
#
# You should change the variables below as follows:
#
# - enable_sync_gateway: setting this to true will cause the script to initialize and
#                        configure Sync Gateway.  If set to false, it will shut down the
#                        Sync Gateway process, which is useful if you are only interested
#                        in running Couchbase Server
# - enable_couchbase_server: setting this to true will cause the script to initialize and
#                            configure Couchbase Server.  If set to false, it will shut down
#                            the Couchbase Server service on the machine, which is useful if
#                            your Sync Gateway config only uses in-memory buckets
# - sg_config_url: should point to a URL where your Sync Gateway configuration is stored
# - couchbase_bucket_name: should contain the name of the Couchbase Server bucket required by
#                          your Sync Gateway configuration
#
enable_couchbase_server=true
enable_sync_gateway=true
sg_config_url=https://raw.githubusercontent.com/couchbase/sync_gateway/master/examples/basic-couchbase-bucket.json
couchbase_bucket_name=default

# ----------------------------- Functions -------------------------------
initialize_couchbase_server() {

    echo "Initializing Couchbase Server"
    couchbase_server_home_path=/opt/couchbase
    couchbase_server_admin=Administrator
    couchbase_server_admin_port=8091
    # The ec2 instance metadata is available at a special ip as described here:
    # http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html
    instance_metadata_ip=169.254.169.254
    public_hostname=$(curl http://${instance_metadata_ip}/latest/meta-data/public-hostname)
    couchbase_server_bucket_ram_mb=$(free -m | awk 'NR==2{printf "%.0f\n", $2*0.8 }')
    password=$(curl http://${instance_metadata_ip}/latest/meta-data/instance-id)
    export couchbase_server_bucket_type=couchbase
    export couchbase_server_bucket_port=11211
    export couchbase_server_bucket_replica=1

    echo "Init Couchbase Cluster + Set RAM"
    ${couchbase_server_home_path}/bin/couchbase-cli cluster-init -c ${public_hostname} \
				 --user=${couchbase_server_admin} \
				 --password=${password} \
				 --cluster-init-username=${couchbase_server_admin} \
				 --cluster-init-password=${password} \
				 --cluster-init-port=${couchbase_server_admin_port} \
				 --cluster-init-ramsize=${couchbase_server_bucket_ram_mb} || exit 1

    echo "Init primary Couchbase Node"
    ${couchbase_server_home_path}/bin/couchbase-cli node-init -c ${public_hostname} \
				 --user=${couchbase_server_admin} \
				 --password=${password} \
				 --cluster-init-username=${couchbase_server_admin} \
				 --node-init-hostname=${public_hostname} || exit 1

    echo "Create new Couchbase buckets"
    # NOTE: if your Sync Gateway configuration requires more Couchbase Server buckets
    # you can create them by copying and pasting this line and hardcoding the --bucket parameter
    ${couchbase_server_home_path}/bin/couchbase-cli bucket-create -c ${public_hostname} \
				 --user=${couchbase_server_admin} \
				 --password=${password} \
				 --bucket=${couchbase_bucket_name} \
				 --enable-flush=1 \
				 --bucket-type=${couchbase_server_bucket_type} \
				 --bucket-port=${couchbase_server_bucket_port} \
				 --bucket-ramsize=${couchbase_server_bucket_ram_mb} \
				 --bucket-replica=${couchbase_server_bucket_replica} --wait || exit 1

    echo "Waiting until Couchbase responding on port 8091"
    COUNTER=0
    until $(curl --output /dev/null --silent --head --fail http://localhost:8091); do
	if [  $COUNTER -gt 10 ]; then
	    echo "Giving up after several retries"
	    exit 1
	fi
	printf '.'
	sleep 5
	let COUNTER=COUNTER+1
    done


    echo "Sleeping to wait until Couchbase Server is ready"
    # When testing, I saw a case where these messages appeared in the Sync Gateway logs:
    # 2016/04/27 22:27:52 Non-healthy node; node details:
    # Hostname=ec2-54-173-225-77.compute-1.amazonaws.com:8091, Status=warmup, ...
    # TODO: this should query the Couchbase Server REST API to check the node is healthy
    # instead of sleeping
    sleep 30
    
}

initialize_sync_gateway() {

    echo "Configuring and restarting Sync Gateway"
    curl ${sg_config_url} > /opt/sync_gateway/etc/sync_gateway.json
    chown sync_gateway:sync_gateway /opt/sync_gateway/etc/sync_gateway.json
    ls -alh /opt/sync_gateway/etc/sync_gateway.json
    cat /opt/sync_gateway/etc/sync_gateway.json
    /etc/init.d/sync_gateway stop
    /etc/init.d/sync_gateway start
    cat /var/log/sync_gateway/sync_gateway_error.log

}

stop_couchbase_server() {
    echo "Stopping Couchbase Server since it has been explicitly disabled"
    service couchbase-server stop
}

stop_sync_gateway() {
    echo "Stopping Sync Gateway since it has been explicitly disabled"
    /etc/init.d/sync_gateway stop
}


# ----------------------------- Main -------------------------------
if [ "$enable_couchbase_server" = true ] ; then
    initialize_couchbase_server
else
    stop_couchbase_server
fi

if [ "$enable_sync_gateway" = true ] ; then
    initialize_sync_gateway
else
    stop_sync_gateway
fi






