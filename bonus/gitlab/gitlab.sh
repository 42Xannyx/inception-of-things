#!/usr/bin/env bash

set -euo pipefail

sudo apt update
sudo apt-get install -y tzdata perl curl libatomic1 postfix

kubectl create namespace gitlab

kubectl apply -n gitlab -f gitlab-deployment.yaml
kubectl apply -n gitlab -f gitlab-service.yaml
kubectl apply -n gitlab -f gitlab-pvc.yaml
kubectl apply -n gitlab -f gitlab-ingress.yaml

kubectl wait --for=condition=ready pod -l app=gitlab -n gitlab --timeout=300s

#display pass
POD_NAME=$(kubectl get pods -n gitlab -l app=gitlab -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $POD_NAME -n gitlab -- grep 'Password:' /etc/gitlab/initial_root_password

#Listen for connection for gitlab
kubectl port-forward svc/gitlab-svc -n gitlab 8085:80

#Get token so we can create a repo and push the config files for argocd
POD_NAME=$(kubectl get pods -n gitlab -l app=gitlab -o jsonpath="{.items[0].metadata.name}")

kubectl exec -it $POD_NAME -n gitlab -- gitlab-rails runner "
user = User.find_by_username('root');
token = user.personal_access_tokens.create(scopes: [:api], name: 'automation-token');
token.set_token('iot-token');
token.save!"
