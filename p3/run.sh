#!/usr/bin/env bash

set -e  

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

for pkg in docker.io docker-compose docker-doc podman-docker containerd runc; do
    sudo apt-get remove -y $pkg 2>/dev/null || true
done

if [[ ! -f "/etc/apt/keyrings/docker.asc" ]]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
fi

if [[ ! -f "/etc/apt/sources.list.d/docker.sources" ]]; then
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
fi

if [[ ! -f ~/.local/bin/kubectl ]]; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mkdir -p ~/.local/bin
    mv ./kubectl ~/.local/bin/kubectl
    
    if ! grep -q '.local/bin' ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
fi

# Install Dokcer
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 

sudo usermod -aG docker $USER

curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

k3d cluster delete p3
k3d cluster create p3 -p "8888:80@loadbalancer"

#Create namespaces and initial config for argo
kubectl create namespace argocd
kubectl create namespace dev

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side

#wait for argocd to be ready
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

#Forward port for argoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>/dev/null & 

sleep 2

#Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

#Pass to Argo
echo $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)

#Conf for custom cluster
kubectl apply -f cluster2.yaml -n argocd
