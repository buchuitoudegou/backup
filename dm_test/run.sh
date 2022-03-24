master_log=/tmp/dm-master.log
worker1_log=/tmp/dm-worker1.log
myipv4=$(ifconfig | grep "inet 192.* broadcast.*" | cut -d" " -f2)
set -x
function start_dm() {
    master_flags="--master-addr=127.0.0.1:8261 --log-file=$master_log --name=master1 --data-dir=$dm_master_data_dir"
    bin/dm-master $master_flags < /dev/null > ${master_log}.std 2>&1 &

    sleep 3

    worker1_flags="--worker-addr=127.0.0.1:8361 --log-file=$worker1_log --join=127.0.0.1:8261 --name=worker1"
    bin/dm-worker $worker1_flags < /dev/null > ${worker1_log}.std 2>&1 &

    sleep 2

    ps -ef | grep -E 'dm-{master|worker}'
}

function cleanup() {
    ps -ef |grep '[d]m-worker'|awk '{print $2}'| xargs -I{} kill {}
    ps -ef |grep '[d]m-master'|awk '{print $2}'| xargs -I{} kill {}
    rm -f $master_log ${master_log}.std
    rm -f $worker1_log ${worker1_log}.std
    rm -f $worker2_log
    rm -rf $dm_master_data_dir
    rm -rf mysql-3306-relay/

    # ps -ef |grep '[t]op'|awk '{print $2}' | xargs -I{} kill {}
    # rm -f cpu-usage.txt
}

function cleanup_tidb() {
    ps -ef | grep 'tidb-server' | grep -v grep | awk '{print $2}' | xargs kill -9
    sleep 2
    ps -ef | grep 'tikv-server' | grep -v grep | awk '{print $2}' | xargs kill -9
    sleep 2
    rm -rf /tmp/tikv1
    ps -ef | grep 'pd-server' | grep -v grep | awk '{print $2}' | xargs kill -9
    sleep 2
    rm -rf pd
}

function create_source() {
    bin/dmctl --master-addr=127.0.0.1:8261 operate-source create source.yaml
}

function start_task() {
    bin/dmctl --master-addr=127.0.0.1:8261 start-task task.yaml
}

function query_task() {
    bin/dmctl --master-addr=127.0.0.1:8261 query-status task.yaml
}

function stop_task() {
    bin/dmctl --master-addr=127.0.0.1:8261 stop-task task.yaml
}

function remove_source() {
    bin/dmctl --master-addr=127.0.0.1:8261 operate-source stop source.yaml
}

function start_tidb_cluster() {
    echo $myipv4
    rm -rf pd
    bin/pd-server --name="pd" \
        --data-dir="pd" \
        --name="pd1" \
        --client-urls="http://0.0.0.0:2379" \
        --peer-urls="http://0.0.0.0:2380" \
        --advertise-client-urls="http://$myipv4:2379" \
        --advertise-peer-urls="http://$myipv4:2380" \
        --initial-cluster="pd1=http://$myipv4:2380" \
        &> pd.log &
    
    sleep 2
    rm -rf /tmp/tikv1
    bin/tikv-server \
        --addr="0.0.0.0:20160" \
        --data-dir="/tmp/tikv1" \
        --advertise-addr="$myipv4:20160" \
        --pd="$myipv4:2379" \
        &> tikv.log &

    sleep 3
    bin/tidb-server --store=tikv \
        --path="$myipv4:2379" \
        &> tidb.log &
    sleep 3
}

function start_all() {
    cleanup
    start_tidb_cluster
    start_dm
    create_source
    start_task
    query_task
}

function stop_all() {
    # stop_task
    # remove_source
    # cleanup
    cleanup_tidb
}

$1