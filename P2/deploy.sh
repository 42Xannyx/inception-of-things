#!/usr/bin/env bash

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg

curl -sfL https://get.k3s.io | sh -s - --node-ip=192.168.56.110

echo "192.168.56.110 app1.com app2.com app3.com" >> /etc/hosts

sudo kubectl apply -f /vagrant/services/deployment.yaml
