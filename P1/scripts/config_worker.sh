#!/bin/bash
apt-get update -y
apt-get install -y curl ca-certificates gnupg lsb-release iptables iproute2 net-tools
# Get the token from the shared folder
TOKEN=$(cat /vagrant/token)

# Install K3s agent (worker) and join the master node
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 K3S_TOKEN=$TOKEN INSTALL_K3S_EXEC="--flannel-iface=enp0s8" sh -
