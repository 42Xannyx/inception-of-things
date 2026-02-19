#!/usr/bin/env bash

set -e  
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

for pkg in docker.io docker-compose docker-doc podman-docker containerd runc; do
    sudo apt-get remove -y $pkg 2>/dev/null || true
done

if [[ ! -f "/etc/apt/keyrings/docker.asc" ]]; then
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc
fi

if [[ ! -f "/etc/apt/sources.list.d/docker.list" ]]; then
	echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
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

if [[ ! -f "/usr/local/bin/argocd" ]]; then 
	VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
	curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
	sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
	rm argocd-linux-amd64
fi

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 

sudo usermod -aG docker $USER

#Create gitlab cluster/pod
CLUSTER=$(k3d cluster list -o json)
if [[ "$CLUSTER" = "[]" ]]; then
	k3d cluster create iot-bonus
fi

if ! kubectl get namespace gitlab > /dev/null 2>&1; then
	kubectl create namespace gitlab
fi

if ! kubectl get namespace argocd > /dev/null 2>&1; then
        kubectl create namespace argocd
fi

if ! kubectl get namespace dev > /dev/null 2>&1; then
        kubectl create namespace dev
fi



kubectl apply -n gitlab -f gitlab-deployment.yaml
kubectl apply -n gitlab -f gitlab-service.yaml
kubectl apply -n gitlab -f gitlab-pvc.yaml
kubectl apply -n gitlab -f gitlab-ingress.yaml


kubectl wait --for=condition=available --timeout=1200s deployment --all -n gitlab

#display pass
POD_NAME=$(kubectl get pods -n gitlab -l app=gitlab -o jsonpath="{.items[0].metadata.name}")

while [ kubectl exec -it $POD_NAME -n gitlab -- grep 'Password:' /etc/gitlab/initial_root_password 2>/dev/null ]; do
	sleep 5
done

until kubectl exec -n gitlab $POD_NAME -- test -f /opt/gitlab/etc/gitlab-rails-rc && \
	kubectl exec -n gitlab "$POD_NAME" -- gitlab-rake db:migrate:status >/dev/null 2>&1; do
    sleep 5
done

#Get token so we can create a repo and push the config files for argocd
kubectl exec -n gitlab $POD_NAME -- gitlab-rails runner "
user = User.find_by_username('root');
token = user.personal_access_tokens.create(scopes: [:api], name: 'automation-token', expires_at: 365.days.from_now);
token.set_token('root-token');
token.save!
puts token.token
"

kubectl port-forward svc/gitlab-svc -n gitlab 8085:80 >/dev/null 2>&1 &
echo -e "You can access gitlab at http://localhost:8085 \n \
Login: root\n \
$(kubectl exec -it $POD_NAME -n gitlab -- grep 'Password:' /etc/gitlab/initial_root_password)"
