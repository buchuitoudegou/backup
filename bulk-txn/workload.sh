
function mysql_exec() {
    mysql -uroot -h 127.0.0.1 -P 4000 -e "$1"
}


function cdc_workload() {
    mysql_exec "drop database if exists test_cdc" # cleanup data
    mysql_exec "create database if not exists test_cdc;"
    mysql_exec "create table if not exists test_cdc.test(\
        a int, \
        b int, \
        primary key(a) \
    );"
    for (( i=0; i < 1000; ++i)) do
        a="$i"
        b=$i+1
        mysql_exec "insert into test_cdc.test values ($a, $b);"
        sleep .1 # sleep 0.1s
    done
}

function lightning_workload() {
    mysql_exec "drop database if exists test_lightning_topsql;"
    mysql_exec "create database if not exists test_lightning_topsql;"
    mysql_exec "create table if not exists test_lightning_topsql.test(\
        a int, \
        b varchar(50), \
        primary key(a) \
    );"
    insert_sql="insert into test_lightning_topsql.test values"
    for (( i=0; i < 100000; ++i )) do
        if [ $i != "0" ]
        then
            insert_sql+=","
        fi
        a="$i"
        b="'sometext_$i'"
        insert_sql+=" ($a, $b)"
    done
    echo "start inserting..."
    echo "$insert_sql"
    mysql_exec $insert_sql
}
$1
