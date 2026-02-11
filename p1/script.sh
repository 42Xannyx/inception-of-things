#!/usr/bin/env bash

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg

if [ "$CONTROLLER" == "true" ]; then
	curl -sfL https://get.k3s.io | K3S_TOKEN=$TOKEN sh -s - \
		--node-ip=192.168.56.110 --advertise-address=192.168.56.110
else
	curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 K3S_TOKEN=$TOKEN sh -s - \
		--node-ip=192.168.56.111
fi

