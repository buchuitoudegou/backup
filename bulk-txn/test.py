import pymysql
import random
import string


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
    ret = ""
    for i in range(cnt):
        ret += random.choice(string.ascii_letters)
    return ret


def test_mysql_insert(conn):
    with conn:
        with conn.cursor() as cursor:
            sql = "create table if not exists test(\
                a int,\
                b varchar(50),\
                primary key(a))"
            cursor.execute(sql)
            sql = "insert into `test` values"
            args = []
            for i in range(count):
                if i != 0:
                    sql += ","
                sql += "(%s, %s)"
                args.append(i)
                args.append(gen_rand_str(30))
            print("inserting...")
            cursor.execute(sql, args)
            conn.commit()


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

count = 100000
test_mysql_insert(conn)
# cleanup_data(conn, "test_lightning_topsql")
