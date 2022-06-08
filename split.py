import os
import re

split_count = 20

os.chdir(f"/home/test_10G_{split_count}")

files = os.listdir(".")

for i in range(split_count - 1):
    os.system(f"cp db.test-schema.sql db.test{i}-schema.sql")
    os.system(f"sed -i s/test/test{i}/ db.test{i}-schema.sql")

pattern = re.compile(r'^db\.test\.000.*\.sql')

data_files = list(filter(lambda name: pattern.match(name), files))
schema_files = list(filter(lambda name: name not in data_files and name != 'db-schema-create.sql' and name != 'metadata', files))

bucket = {key: [] for key in schema_files}

idx = 0

for i in range(len(data_files)):
    key = schema_files[idx]
    bucket[key].append(data_files[i])
    idx = (idx + 1) % len(schema_files)

for key in bucket:
    idx = len('db.test')
    print(key, key[idx], '-')
    if key[idx] == '-':
        continue
    else:
        suffix = key[idx:key.find('-')]
        for file in bucket[key]:
            idx = len('db.test')
            new_file = 'db.test' + suffix + file[idx:]
            os.system(f'mv {file} {new_file}')
