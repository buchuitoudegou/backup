function run_test() {
    logfile=$2
    quota=$1
    outfile=$3
    cleanup_data
    rm -rf $logfile
    nohup /home/tidb/bin/tidb-lightning --config /home/backup/lightning.toml &
    pid1="$!"
    sleep 2
    nohup lightning_log/bin/main --disk-quota $quota --log $logfile > $outfile 2>&1 &
    wait ${pid1}
}

function cleanup_data() {
    mysql -u root -h 127.0.0.1 -P 4000 -e "drop database if exists db;"
}

disk_quota=("1GB" "5GB" "10GB")

check_interval=("5s" "10s" "30s")

out_log="/home/test.out"

function run_check_interval_test() {
    for i in "${disk_quota[@]}"
    do
        for j in "${check_interval[@]}"
        do 
            ilog="${i}_${j}.log"
            lightning_log="file = \"\/home\/tidb-lightning_${i}_${j}.log\""
            # sed -i "s/^disk-quota = .*/disk-quota = \"${test_case}\"/" lightning.toml
            sed -i "s/^file = .*/${lightning_log}/" /home/backup/lightning.toml
            sed -i "s/^disk-quota = .*/disk-quota = \"${i}\"/" /home/backup/lightning.toml
            sed -i "s/^check-disk-quota = .*/check-disk-quota = \"${j}\"/" /home/backup/lightning.toml
            run_test $i "/home/tidb-lightning_${i}_${j}.log" ${ilog}
            echo "${i}_${j}:" >> ${out_log}
            tail "/home/tidb-lightning_${i}_${j}.log" | grep "the whole procedure completed" | tee -a ${out_log}
        done
    done
}

function repeat_performance_test() {
    for k in {1..10}
    do
        for i in "${disk_quota[@]}"
        do
            for j in "${check_interval[@]}"
            do 
                lightning_log="file = \"\/home\/tidb-lightning_${i}_${j}.log\""
                # sed -i "s/^disk-quota = .*/disk-quota = \"${test_case}\"/" lightning.toml
                sed -i "s/^file = .*/${lightning_log}/" /home/backup/lightning.toml
                sed -i "s/^disk-quota = .*/disk-quota = \"${i}\"/" /home/backup/lightning.toml
                sed -i "s/^check-disk-quota = .*/check-disk-quota = \"${j}\"/" /home/backup/lightning.toml
                cleanup_data
                rm -rf $logfile
                echo "${i}_${j}:" >> ${out_log}
                nohup /home/tidb/bin/tidb-lightning --config /home/backup/lightning.toml &
                pid1="$!"
                wait ${pid1}
                tail "/home/tidb-lightning_${i}_${j}.log" | grep "the whole procedure completed" | tee -a ${out_log}
            done
        done
    done
}

$1