[ -z "$RGW_AGENT_PATH" ] && RGW_AGENT_PATH="./"
[ -z "$RGW_CEPH_PATH" ] && RGW_CEPH_PATH="./"
[ -z "$RGW_MASTER_PATH" ] && RGW_MASTER_PATH="./cluster-master"
[ -z "$RGW_SLAVE_PATH" ] && RGW_SLAVE_PATH="./cluster-slave"

RGW_AGENT_BIN="$RGW_AGENT_PATH/radosgw-agent"
RGW_AGENT_CONF="$RGW_AGENT_PATH/conf.yaml"

RGW_CEPH_RGW_ADMIN="$RGW_CEPH_PATH/radosgw-admin"

[ -z "$RGW_SRC_ACCESS_KEY" ] && echo "You must specify an access key for source cluster" && exit 1
[ -z "$RGW_SRC_SECRET_KEY" ] && echo "You must specify an secret key for source cluster" && exit 1
[ -z "$RGW_DST_ACCESS_KEY" ] && echo "You must specify an access key for destination cluster" && exit 1
[ -z "$RGW_DST_SECRET_KEY" ] && echo "You must specify an secret key for destination cluster" && exit 1
[ -z "$RGW_SRC_HOST" ] && echo "You must specify the host for source cluster" && exit 1
[ -z "$RGW_SRC_PORT" ] && echo "You must specify the port for source cluster" && exit 1
[ -z "$RGW_DST_HOST" ] && echo "You must specify the host for destination cluster" && exit 1
[ -z "$RGW_DST_PORT" ] && echo "You must specify the port for destination cluster" && exit 1
[ -z "$RGW_SRC_ZONE" ] && echo "You must specify an acces key for source cluster" && exit 1
[ -z "$RGW_DST_ZONE" ] && echo "You must specify an acces key for source cluster" && exit 1
[ ! -f "$RGW_AGENT_BIN" ] && echo "$RGW_AGENT_BIN:File not found" && exit 1

echo "WARNING! s3cmd should be configure to work with the master-cluster"

echo "Creating a few buckets"
for i in {1..10}; do s3cmd mb s3://BUCKET$i ; done
echo "$i Bucket(s) created"

agent_conf="src_access_key : \"0555b35654ad1656d804\"
src_secret_key : \"h7GhxuBLTrlhVUyxSPUKUV8r/2EI4ngqJxD7iBdBYLhwluN30JaT3Q==\"
src_host : \"localhost\"
src_port : 8000
src_zone : \"master-1\"
dest_access_key : \"0555b35654ad1656d804\"
dest_secret_key : \"h7GhxuBLTrlhVUyxSPUKUV8r/2EI4ngqJxD7iBdBYLhwluN30JaT3Q==\"
dest_host : \"localhost\"
dest_port : 8001
dest_zone : \"slave-1\"
daemon_id : 1337"
cat <<EOF > $RGW_AGENT_CONF
$agent_conf
EOF

echo "Creating configuration for agent"
cat $RGW_AGENT_CONF
echo "Done"

echo "Checking that listed buckets are still not in sync"
diff <($RGW_CEPH_RGW_ADMIN -c $RGW_MASTER_PATH/ceph.conf buckets list) <($RGW_CEPH_RGW_ADMIN -c $RGW_SLAVE_PATH/ceph.conf buckets list)
echo "Done"

echo "Now syncing both clusters"
$RGW_AGENT_BIN -c $RGW_AGENT_CONF --sync-scope=full
echo "Done"

echo "Checking that listed buckets are the same on both side"
diff <($RGW_CEPH_RGW_ADMIN -c $RGW_MASTER_PATH/ceph.conf buckets list) <($RGW_CEPH_RGW_ADMIN -c $RGW_SLAVE_PATH/ceph.conf buckets list)
metadata_section_list=`$RGW_CEPH_RGW_ADMIN -c $RGW_MASTER_PATH/ceph.conf metadata list | sed "s/\[//g" | sed "s/\]//g" | sed "s/\"//g"`
metadata_section_list=$(echo $metadata_section_list | tr "," "\n")
for metadata_section in $metadata_section_list
do
	metadata_list=`$RGW_CEPH_RGW_ADMIN -c $RGW_MASTER_PATH/ceph.conf metadata list $metadata_section | sed "s/\[//g" | sed "s/\]//g" | sed "s/\"//g"`
	metadata_list=$(echo $metadata_list | tr "," "\n")
	for metadata in $metadata_list
	do
		diff <($RGW_CEPH_RGW_ADMIN -c $RGW_MASTER_PATH/ceph.conf metadata get $metadata_section:$metadata) <($RGW_CEPH_RGW_ADMIN -c $RGW_SLAVE_PATH/ceph.conf metadata get $metadata_section:$metadata)
	done
done
#diff -- $metadata_list <($RGW_CEPH_RGW_ADMIN -c $RGW_SLAVE_PATH/ceph.conf metadata list)
echo "Done"
