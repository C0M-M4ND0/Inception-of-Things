#!/bin/sh

sudo -i

export K3S_KUBECONFIG_MODE="644"
export INSTALL_K3S_EXEC="--bind-address=$MASTER --node-external-ip=$MASTER --flannel-iface=eth1"
curl -sfL https://get.k3s.io | sh -
sleep 10
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --zone=public --add-port=6443/tcp --permanent
firewall-cmd --reload
cp /var/lib/rancher/k3s/server/token /tmp/shared/
# cp /etc/rancher/k3s/k3s.yaml /tmp/shared/
