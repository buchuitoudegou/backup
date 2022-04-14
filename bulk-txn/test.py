import pymysql
import random
import string
from multiprocessing import Process
import copy

cache = ""


def test_tidb_topsql(conn):
    with conn:
        with conn.cursor() as cursor:
            sql = "insert into `test` values"
            for i in range(count):
                if i != 0:
                    sql += ","
                sql += "(%s, %s)"
            args = [[i + 10, i + 10] for i in range(count)]
            args = [item for sublist in args for item in sublist]
            cursor.execute(sql, args)
            conn.commit()

    with conn:
        with conn.cursor() as cursor:
            sql = (
                f"select * from `test` where a%{random.randint(1, 7)}=0 order by b desc"
            )
            cursor.execute(sql)
            result = cursor.fetchall()


def gen_rand_str(cnt=20):
    global cache
    ret = cache
    if ret == "":
        for i in range(cnt):
            ret += random.choice(string.ascii_letters)
        cache = ret
        return ret
    else:
        change_idx = random.randint(0, cnt - 1)
        ret = list(ret)
        ret[change_idx] = random.choice(string.ascii_letters)
        return "".join(ret)


def test_mysql_insert(conn):
    multi_procs = []
    with conn.cursor() as cursor:
        sql = "create table if not exists test(\
            a int,\
            b varchar(1000),\
            primary key(a))"
        cursor.execute(sql)
        conn.commit()
    sql = "insert into `test` values"
    args = []
    for i in range(count):
        if len(args) != 0:
            sql += ","
        sql += "(%s, %s)"
        args.append(i)
        args.append(gen_rand_str(999))
        if i > 0 and i % 100000 == 0:
            print(f"inserting {i}...")

            def exec_sql(sql, args):
                conn = pymysql.connect(
                    host="localhost",
                    user="root",
                    database="test_lightning_topsql",
                    port=4000,
                )
                cursor = conn.cursor()
                cursor.execute(sql, args)
                conn.commit()

            p = Process(
                target=exec_sql,
                args=(
                    sql,
                    copy.deepcopy(args),
                ),
            )
            p.start()
            multi_procs.append(p)
            sql = "insert into `test` values"
            args = []

    if len(args) != 0:
        cursor = conn.cursor()
        cursor.execute(sql, args)
        conn.commit()
    for p in multi_procs:
        p.join()


def cleanup_data(conn, db):
    with conn:
        with conn.cursor() as cursor:
            cursor.execute(f"drop database {db}")
            cursor.execute("drop database dm_meta")
            conn.commit()


# conn = pymysql.connect(host="localhost", user="root", database="test_backup", port=4000)

conn = pymysql.connect(
    host="localhost", user="root", database="test_lightning_topsql", port=4000
)
# conn = pymysql.connect(
#     host="localhost",
#     user="root",
#     database="test_lightning_topsql",
#     port=3306,
#     passwd="123456",
# )

count = 10000000
test_mysql_insert(conn)
# cleanup_data(conn, "test_lightning_topsql")
