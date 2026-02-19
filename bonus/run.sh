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

if [[ ! -f "/usr/local/bin/argocd" ]]; then 
	VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
	curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
	sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
	rm argocd-linux-amd64
fi

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 

sudo usermod -aG docker $USER

curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash

curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

k3d cluster delete argocluster
k3d cluster create --config k3d-cluster.yml

kubectl create namespace dev
kubectl create namespace gitlab
kubectl create namespace argocd

kubectl replace -n argocd --force -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=600s deployment --all -n argocd

helm repo add gitlab https://charts.gitlab.io/
helm repo update

kubectl apply -f gitlab-cluster.yml

kubectl wait --for=condition=complete --timeout=600s job/helm-install-gitlab -n kube-system
kubectl wait --for=condition=available --timeout=1200s deployment --all -n gitlab

fuser -k 8181/tcp 2>/dev/null || true
fuser -k 8080/tcp 2>/dev/null || true
sleep 1

kubectl port-forward svc/argocd-server -n argocd 8080:443 &
kubectl port-forward -n gitlab svc/gitlab-webservice-default 8181:8181 &

sleep 5

PASSWORD_GITLAB=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d)
PASSWORD_ARGOCD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

argocd login localhost:8080 \
  --username admin \
  --password "$PASSWORD_ARGOCD" \
  --insecure

kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: iot-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/root/iot-app.git
    targetRevision: HEAD
    path: .         
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true       
      selfHeal: true    
    syncOptions:
      - CreateNamespace=true
EOF

TOOLBOX_POD=$(kubectl get pods -n gitlab -l app=toolbox --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

kubectl wait --for=condition=available --timeout=300s deployment/gitlab-toolbox -n gitlab

# Inside Pod
kubectl exec -n gitlab $TOOLBOX_POD -- gitlab-rails runner "
user = User.find_by_username('root')
token = user.personal_access_tokens.create(
  scopes: [:api],
  name: 'automation-token',
  expires_at: 365.days.from_now
)
token.set_token('root-token')
token.save!
puts token.token
"
# Exit Pod

CONTENT=$(base64 -w 0 docker.yml)
curl -H "PRIVATE-TOKEN: root-token" -X POST "http://localhost:8181/api/v4/projects?name=iot-app&visibility=public"
curl -s -X POST "http://localhost:8181/api/v4/projects/1/repository/files/docker.yml" \
  -H "PRIVATE-TOKEN: root-token" \
  -H "Content-Type: application/json" \
  -d "{
    \"branch\": \"main\",
    \"content\": \"$CONTENT\",
    \"encoding\": \"base64\",
    \"commit_message\": \"Add deployment manifest\"
  }"

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/root/iot-app.git
  username: root
  password: root-token
  insecure: "true"
EOF

echo "URL: localhost:8080"
echo "Username: admin"
echo "ARGOCD Password: $PASSWORD_ARGOCD"

echo "URL: localhost:8181"
echo "Username: root"
echo "GitLab Password: $PASSWORD_GITLAB"
