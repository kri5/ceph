./stop.sh
rm -fr cluster-*
mkdir -p cluster-master/dev
mkdir -p cluster-master/out
mkdir -p cluster-slave/dev
mkdir -p cluster-slave/out
export PYTHONPATH=./pybind
export LD_LIBRARY_PATH=.libs
akey='0555b35654ad1656d804'
skey='h7GhxuBLTrlhVUyxSPUKUV8r/2EI4ngqJxD7iBdBYLhwluN30JaT3Q=='
CEPH_DIR="$PWD/cluster-master" CEPH_PORT=6789 CEPH_RGW_PORT=8000 ./vstart.sh -r -l -n -x mon osd
CEPH_DIR="$PWD/cluster-slave" CEPH_PORT=6989 CEPH_RGW_PORT=8001 ./vstart.sh -r -l -n -x mon osd
./radosgw-admin -c cluster-master/ceph.conf region set < master.region
./radosgw-admin -c cluster-master/ceph.conf region set < slave.region
./radosgw-admin -c cluster-master/ceph.conf region default --rgw-region=master
./radosgw-admin -c cluster-master/ceph.conf zone set --rgw-region=master < master.zone
./radosgw-admin -c cluster-slave/ceph.conf region set < master.region 
./radosgw-admin -c cluster-slave/ceph.conf region set < slave.region
./radosgw-admin -c cluster-slave/ceph.conf region default --rgw-region=slave
./radosgw-admin -c cluster-slave/ceph.conf zone set --rgw-region=slave < slave.zone 
./rados -c cluster-master/ceph.conf -p .rgw.root rm region_info.default
./rados -c cluster-master/ceph.conf -p .rgw.root rm zone_info.default
./rados -c cluster-slave/ceph.conf -p .rgw.root rm region_info.default
./rados -c cluster-slave/ceph.conf -p .rgw.root rm zone_info.default
./rados -c cluster-master/ceph.conf mkpool .rgw.buckets
./rados -c cluster-slave/ceph.conf mkpool .rgw.buckets
./rados -c cluster-master/ceph.conf mkpool .rgw.buckets.index
./rados -c cluster-slave/ceph.conf mkpool .rgw.buckets.index
./rados -c cluster-master/ceph.conf mkpool .log
./rados -c cluster-slave/ceph.conf mkpool .log
./radosgw-admin -c cluster-master/ceph.conf regionmap update
./radosgw-admin -c cluster-slave/ceph.conf regionmap update
killall -w lt-radosgw
./radosgw -n client.radosgw.rgw0 -c cluster-master/ceph.conf
./radosgw -n client.radosgw.rgw0 -c cluster-slave/ceph.conf
