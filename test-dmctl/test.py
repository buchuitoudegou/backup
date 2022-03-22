import os
import sys
import shlex
import subprocess

cmds = []
expect = []

# read from `test_cmd`
with open('./test-dmctl/test_cmd', 'r') as f:
    text = f.read()
    text = text.split('\n')
    for line in text:
        if line.find('[label]') >= 0:
            # label string
            if line.find('success') >= 0:
                expect.append(True)
            else:
                expect.append(False)
        elif len(line) > 0:
            cmds.append(line)

# test all
os.chdir('../tiflow')
err_cmds = []
err_msgs = []

for idx in range(len(cmds)):
    args = shlex.split(cmds[idx])
    popen = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, outerr = popen.communicate(timeout=2)
    err_result = output.decode().find('Error') >= 0 or outerr.decode().find('Error') >= 0
    if err_result and expect[idx]:
        # incorrect: expect true but get false
        err_cmds.append(cmds[idx])
        err_msgs.append(outerr.decode())
    elif not err_result and not expect[idx]:
        # incorrect: expect false but get true
        err_cmds.append(cmds[idx])
        err_msgs.append(outerr.decode())

if len(err_cmds) > 0:
    for idx in range(len(err_cmds)):
        print(f'{err_cmds[idx]}\t{err_msgs[idx]}')
else:
    print('all test succeeds')