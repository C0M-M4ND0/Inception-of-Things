#!/bin/bash

sudo -i


export K3S_KUBECONFIG_MODE="644"
export INSTALL_K3S_EXEC="--bind-address=$MASTER --node-external-ip=$MASTER --flannel-iface=enp0s8"
if [ ! -x "/usr/local/bin/k3s" ]; then
    curl -sfL https://get.k3s.io | sh -
fi

if ! command -v docker &> /dev/null; then
    apt update
    apt install -y docker.io
    systemctl enable docker
    systemctl start docker
fi


docker build -t app1:latest /tmp/confs/apps/app1
docker build -t app2:latest /tmp/confs/apps/app2
docker build -t app3:latest /tmp/confs/apps/app3

cd /tmp
docker save --output app1.tar app1:latest
docker save --output app2.tar app2:latest
docker save --output app3.tar app3:latest
/usr/local/bin/k3s ctr images import /tmp/app1.tar
/usr/local/bin/k3s ctr images import /tmp/app2.tar
/usr/local/bin/k3s ctr images import /tmp/app3.tar
/usr/local/bin/k3s kubectl apply -f /tmp/confs/apps/app1/deployment-app1.yaml
/usr/local/bin/k3s kubectl apply -f /tmp/confs/apps/app2/deployment-app2.yaml
/usr/local/bin/k3s kubectl apply -f /tmp/confs/apps/app3/deployment-app3.yaml

#expos pods to outside (service)
/usr/local/bin/k3s kubectl expose -f /tmp/confs/apps/app1/deployment-app1.yaml --port=80 --target-port=80
/usr/local/bin/k3s kubectl expose -f /tmp/confs/apps/app2/deployment-app2.yaml --port=80 --target-port=80
/usr/local/bin/k3s kubectl expose -f /tmp/confs/apps/app3/deployment-app3.yaml --port=80 --target-port=80
#expose service to outside (ingress)
/usr/local/bin/k3s kubectl apply -f /tmp/confs/ingress.yaml


