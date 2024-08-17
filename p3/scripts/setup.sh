#!/bin/bash

set -e

# Check if script is running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo."
    exit 1
fi

# Install git if not already installed
if ! command -v git &> /dev/null; then
    apt update
    apt install -y git
fi

# Install docker if not already installed
if ! command -v docker &> /dev/null; then
    apt update
    apt install -y docker.io
    systemctl enable docker
    systemctl start docker
fi

#Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -rf kubectl

#Install k3d
curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash

#Create k3d cluster
/usr/local/bin/k3d cluster create --wait -a 1

#Set kubeconfig
# Check if ~/kube folder exists, if not create it
if [ ! -d ~/.kube ]; then
    mkdir ~/.kube
fi

/usr/local/bin/k3d kubeconfig get k3s-default > ~/.kube/config
export KUBECONFIG=~/.kube/config

#Create namespaces
/usr/local/bin/kubectl create namespace argocd
/usr/local/bin/kubectl create namespace dev

#Install argocd
/usr/local/bin/kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

#Wait for ArgoCD components to be ready
echo -n "Waiting for ArgoCD components to be ready..."
while [ -z "$argocd_ready" ]; do
    argocd_ready=$(/usr/local/bin/kubectl -n argocd get all 2>/dev/null | awk '{print $3}' | grep -v -E "^(Running|Completed)$" | wc -l)
    sleep 2
    echo -n "."
done
echo

#Function to start port-forwarding
start_port_forwarding() {
    /usr/local/bin/kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 31443:443 > /tmp/port-forward.log 2>&1
}

#Check if kubectl port-forward is successful, if not, retry every 5 seconds
echo -n "waiting for ArgoCD port-forwarding to be successful..."
while true; do
    if curl -s --max-time 2 http://localhost:31443 &> /dev/null; then
        echo
        echo "ArgoCD port-forwarding is successful."
        break
    else
        echo -n "."
        start_port_forwarding &> /dev/null &
        sleep 5
    fi
done

#Print argocd password (waiting for the secret to be available)
echo -n "Waiting for ArgoCD initial admin password..."
while [ -z "$argocd_password" ]; do
    argocd_password=$(/usr/local/bin/kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null)
    sleep 2
    echo -n "."
done
echo
echo -e "ArgoCD password: \e[1;32m$argocd_password\e[0m"

#Clone app from github repository to /tmp
git clone https://github.com/C0M-M4ND0/oabdelha.git /tmp/oabdelha

#Apply application manifest
/usr/local/bin/kubectl apply -f /tmp/oabdelha/application.yaml --wait
