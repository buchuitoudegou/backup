if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    myipv4=$(hostname -I|sed 's/.$//'|cut -d" " -f1)
else
    myipv4=$(ifconfig | grep "inet 192.* broadcast.*" | cut -d" " -f2)
fi

function deploy_dm() {
    cat ./topology.yaml | sed s/localipv4/${myipv4}/ > temp.yaml

    tiup dm deploy dm-test v6.0.0 ./temp.yaml --user root -p

    rm /dm-deploy/dm-master-8261/bin/dm-master/dm-master
    ln -sf /home/tiflow/bin/dm-master /dm-deploy/dm-master-8261/bin/dm-master/dm-master
    rm /dm-deploy/dm-worker-8262/bin/dm-worker/dm-worker
    ln -sf /home/tiflow/bin/dm-worker /dm-deploy/dm-worker-8262/bin/dm-worker/dm-worker
    ln -sf /home/tiflow/dm/metrics/grafana/DM-Monitor-Professional.json /dm-deploy/grafana-3000/dashboards/DM-Monitor-Professional.json
    ln -sf /home/tiflow/dm/metrics/grafana/DM-Monitor-Professional.json /dm-deploy/grafana-3000/bin/DM-Monitor-Professional.json
    ln -sf /home/tiflow/dm/metrics/grafana/DM-Monitor-Professional.json /dm-deploy/dm-worker-8262/bin/dm-worker/scripts/DM-Monitor-Professional.json
    ln -sf /home/tiflow/dm/metrics/grafana/DM-Monitor-Professional.json /dm-deploy/dm-master-8261/bin/dm-master/scripts/DM-Monitor-Professional.json
    ln -sf /home/tiflow/dm/metrics/grafana/DM-Monitor-Professional.json /root/.tiup/components/dmctl/v6.0.0/dmctl/scripts/DM-Monitor-Professional.json
}

function deploy_tidb() {
    cat ./tidb.yaml | sed s/localipv4/${myipv4}/ > temp.yaml

    tiup cluster deploy tidb-test v6.0.0 ./temp.yaml --user root -p
}

$1