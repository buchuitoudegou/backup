#!/usr/bin/env bash
# add this to /etc/hosts
# mysql3306.host.playground
# dm.host.playground
# downstream.host.playground
set -x

export mysql_host=mysql3306.host.playground
export dm_host=dm.host.playground
export downstream_host=downstream.host.playground
export downstream_port=3307

current_user=$(whoami)
export DM_MASTER_ADDR=$dm_host:8261
master_log=/tmp/dm-master.log
worker1_log=/tmp/dm-worker1.log
worker2_log=/tmp/dm-worker2.log
dm_master_data_dir=/tmp/dm-data

function drop_os_cache() {
    if [ "$(uname -s)" = "Linux" ]; then
        ssh ${current_user}@$mysql_host "sync; echo 3 > /proc/sys/vm/drop_caches"
        ssh ${current_user}@$dm_host "sync; echo 3 > /proc/sys/vm/drop_caches"
        ssh ${current_user}@$downstream_host "sync; echo 3 > /proc/sys/vm/drop_caches"
    fi
}

function start_dm() {
    extra_debug_flag="--continue"
    dlv_flags="$extra_debug_flag --headless=true --api-version=2 --accept-multiclient"
    master_flags="--master-addr=127.0.0.1:8261 --log-file=$master_log --name=master1 --data-dir=$dm_master_data_dir"
    nohup dlv $dlv_flags --listen=:2344 exec bin/dm-master -- $master_flags < /dev/null > ${master_log}.std 2>&1 &
#    nohup bin/dm-master ${master_flags} < /dev/null > ${master_log}.std 2>&1 &

    # worker只能注册到leader，没选出leader时会报错退出
    sleep 3

    worker1_flags="--worker-addr=127.0.0.1:8361 --log-file=$worker1_log --join=127.0.0.1:8261 --name=worker1"
    nohup dlv $dlv_flags --listen=:2345 exec bin/dm-worker -- $worker1_flags < /dev/null > ${worker1_log}.std 2>&1 &
    #GODEBUG=gctrace=1 nohup bin/dm-worker ${worker1_flags} < /dev/null > ${worker1_log}.std 2>&1 &

    sleep 2
    ps -ef |grep -E 'dm-(master|worker)'
}

function cleanup() {
    ps -ef |grep '[d]m-worker'|awk '{print $2}'| xargs -I{} kill {}
    ps -ef |grep '[d]m-master'|awk '{print $2}'| xargs -I{} kill {}
    rm -f $master_log ${master_log}.std
    rm -f $worker1_log ${worker1_log}.std
    rm -f $worker2_log
    rm -rf $dm_master_data_dir
    rm -rf mysql-3306-relay/

#    mysql -h$mysql_host -uroot -e "drop database if exists test"
#    mysql -h$mysql_host -uroot -e "reset master"
#    mysql -h${downstream_host} -P${downstream_port} -uroot -e "drop database if exists test"
#    mysql -h${downstream_host} -P${downstream_port} -uroot -e "drop database if exists dm_meta"

    ps -ef |grep '[t]op'|awk '{print $2}' | xargs -I{} kill {}
#    ssh ${current_user}@$mysql_host "ps -ef |grep '[s]ysbench'|awk '{print $2}' | xargs -I{} kill {}"
    rm -f cpu-usage.txt
}
cleanup
start_dm
# bin/dmctl operate-source create mysql-3306.yaml
# bin/dmctl start-task task-mysql8-json.yaml
exit

function init_db_table_for_latency_cpu_test() {
    mysql -h$mysql_host -uroot -e "create database if not exists test"
    ssh ${current_user}@$mysql_host "sysbench --tables=$table_cnt --db-driver=mysql --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-db=test --mysql-user=root --mysql-password=123456 oltp_read_write prepare"
    for i in $(seq 1 $table_cnt); do mysql -h$mysql_host -uroot -e "alter table test.sbtest$i add column upts timestamp(6) default CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)"; done
    mysql -h$mysql_host -uroot -e "reset master"
    mysql -h$downstream_host -P${downstream_port} -uroot -e "drop database if exists test"
    mysql -h$downstream_host -P${downstream_port} -uroot -e "drop database dm_meta"
}

function operate_source_task_relay_for_latency_test() {
    relay=$1
    task_cnt=$2

    bin/dmctl operate-source create mysql-3306.yaml

    if [ "$task_cnt" = "1" ]; then
        bin/dmctl start-task latency-task.yaml
    else
        for i in $(seq 1 $task_cnt); do
            task_name=sbtest${i}
            cp sbtest-task.yaml sbtest-task-tmp.yaml
            sed -i 's/TBL_NAME/'$task_name'/g' sbtest-task-tmp.yaml
            sed -i 's/TIDB_HOST/'$downstream_host'/g' sbtest-task-tmp.yaml
            bin/dmctl start-task sbtest-task-tmp.yaml
            rm sbtest-task-tmp.yaml
        done
    fi

    if [ "$relay" = "on" ]; then
        echo "start relay..."
        bin/dmctl start-relay -s mysql-3306 worker1
    fi
}

function monitor_dm_worker_cpu() {
    nohup top -p $(ps -ef |grep '[d]m-worker'|awk '{print $2}') -d 1 -b > cpu-usage.txt &
}

function run_sysbench() {
    ssh ${current_user}@$mysql_host "cd /root/j; nohup sysbench --tables=$table_cnt --time=900 --db-driver=mysql --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-db=test --mysql-user=root --mysql-password=123456 oltp_read_write run </dev/null > nohup.out 2>&1 &"
}

function add_downts_column() {
    table_cnt=$1
    for i in $(seq 1 $table_cnt); do
        mysql -u root -h$downstream_host -P${downstream_port} -e "alter table test.sbtest$i  add column downts timestamp(6) default CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6);";
    done
}

function show_task_status_for_latency_test() {
    if [ "$task_cnt" = "1" ]; then
        bin/dmctl query-status latency | jq '.sources[0].sourceStatus'
    else
        for i in $(seq 1 $task_cnt); do
            task_name=sbtest${i}
            bin/dmctl query-status $task_name | jq '.sources[0].sourceStatus'
        done
    fi
}

function gen_result() {
    suffix=$1
    if [ "$suffix" = '' ]; then
        echo "invalid suffix"
        exit 1
    fi

    grep 'dm-worker' cpu-usage.txt | awk '{print $9}' > cpu_$suffix.log
    grep '^gc' /tmp/dm-worker1.log.std > gc_$suffix.log
}

function run_one_round() {
    code=$1
    type=$2
    tbl_cnt=$3
    task_cnt=$4
    rm -rf bin
    cp -rf bin-$code bin
    ./run.sh $type $tbl_cnt $task_cnt
    sleep 900
    suffix=${code}_${type}_${tbl_cnt}_${task_cnt}
    ./extract_diff.py $tbl_cnt > latency_${suffix}.log
    gen_result $suffix
}

# run_one_round new relay 4 4
run_one_round new no_relay 4 4
# run_one_round base relay 4 4
# run_one_round base no_relay 4 4

# run_one_round new relay 10 10
# run_one_round new no_relay 10 10
# run_one_round base relay 10 10
# run_one_round base no_relay 10 10
