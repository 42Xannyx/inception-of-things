#!/usr/bin/env bash

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg

curl -sfL https://get.k3s.io | sh -s - --node-ip=192.168.56.110 

sudo kubectl apply -f /vagrant/services/app1.yml
sudo kubectl apply -f /vagrant/services/app2.yml
sudo kubectl apply -f /vagrant/services/app3.yml
sudo kubectl apply -f /vagrant/services/ingress.yml

sudo kubectl wait --for=condition=available --timeout=300s deployment --all

echo "192.168.56.110 app1.com app2.com app3.com" | sudo tee -a /etc/hosts

