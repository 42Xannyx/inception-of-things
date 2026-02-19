#!/usr/bin/env bash

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
echo "ArgoCD URL: http://localhost:8080\n \
Login: admin\n \
Password: $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)\n"

#Conf for custom cluster
kubectl apply -f argo-deployment.yaml -n argocd
