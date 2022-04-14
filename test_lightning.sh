myipv4=$(hostname -I|sed 's/.$//'|cut -d" " -f1)
test_cases=("1B" "1KB" "1MB" "100MB" "1GB" "10GB" "20GB")
# test_cases=("20GB")
result_file="result.csv"
function adjust_ipv4() {
    sed -i "s/pd-addr = .*/pd-addr = \"$myipv4:2379\"/" lightning.toml
    sed -i "s/host = .*/host = \"$myipv4\"/" lightning.toml
}

function run_test() {
    for j in {1..10}
    do
        echo "testing $j..."
        for test_case in "${test_cases[@]}"
        do
            sed -i "s/^disk-quota = .*/disk-quota = \"${test_case}\"/" lightning.toml
            # echo "[cron]" >> lightning.toml
            # echo "check-disk-quota = \"10s\"" >> lightning.toml
            t=$(bash -c "time /home/tidb/bin/tidb-lightning --config lightning.toml &> /dev/null" 2>&1|cut -f2)
            ret=""
            for i in $t
            do
                ret="$ret$i,"
            done
            ret="$ret$test_case"
            echo $ret >> result.csv
            cleanup_data
        done
    done
}

function cleanup_data() {
    mysql -uroot -h 127.0.0.1 -P 4000 -e "drop table test_lightning_topsql.test"
}

# sed -i 's/disk-quota = .*/disk-quota = "10GiB"/' lightning.toml
# adjust_ipv4
if [ -f "$result_file" ] ; then
    rm "$result_file"
fi
touch $result_file
echo "real_time,user_time,sys_time,disk_quota" >> result.csv
run_test
