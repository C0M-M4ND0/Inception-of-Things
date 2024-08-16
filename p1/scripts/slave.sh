#!/bin/sh

sudo -i

export K3S_TOKEN_FILE=/tmp/shared/token
export K3S_URL=https://$MASTER:6443
export INSTALL_K3S_EXEC="--flannel-iface=eth1"
curl -sfL https://get.k3s.io | sh -
