#!/usr/bin/env bash

#needed_tools=()

#if ! [ -x "$(command -v k3d)" ]; then
#  needed_tools+=("k3d")
#fi
#if ! [ -x "$(command -v kubectl)" ]; then
#  needed_tools+=("kubectl")
#fi
#if ! [ -x "$(command -v docker)" ]; then
#  needed_tools+=("docker")
#fi
#if ! [ -x "$(command -v helm)" ]; then
#  needed_tools+=("helm")
#fi
#if ! [ -x "$(command -v kubeseal)" ]; then
#  needed_tools+=("kubeseal")
#fi

#if [ ${#needed_tools[@]} != "0" ]; then
#  echo "The following tools are missing:"
#  for item in "${needed_tools[@]}"; do
#    echo "$item"
#  done
#  exit 1
#fi

#################
# Setup cluster #
#################

k3d cluster create --config k3d.yaml
kubectl config use-context k3d-argo-cd-poc

kubectl create namespace argocd

################
# Build images #
################

docker build -t localhost:5000/example/app ./common-src
docker image push localhost:5000/example/app

#################
# Setup Argo CD #
#################

echo ""
echo "getting helm repository argo .."
helm repo add argo https://argoproj.github.io/argo-helm
echo ""
echo "installing argo-cd .."
helm install argocd argo/argo-cd -n argocd -f infra/argo/argo-cd-config.yaml --wait --timeout 8m0s

kubectl -n argocd delete secret argocd-initial-admin-secret --ignore-not-found=true
# is 1234
kubectl -n argocd patch secret argocd-secret -p '{"stringData": {"admin.password": "$2a$12$lsj.ZMc45C3g3zDwF1E4nufjDE8LsmT/8wBBP0WORi0TcAeQ.1Wje"}}'

###############################
# Apply all argo applications #
###############################

kubectl apply -f infra/argo/sealed-secrets-application.yaml

kubectl apply -f infra/application-dev.yaml
kubectl apply -f infra/application-prod.yaml

##################################
# Seal secrets with your cluster #
##################################

sealed_secrets_rolled_out=1
while [ $sealed_secrets_rolled_out -ne 0 ]; do
  kubectl rollout status deploy/sealed-secrets-controller -n kube-system
  sealed_secrets_rolled_out=$?
done

kubeseal < infra/secrets/raw/example-dev.json > infra/secrets/dev/sealed-example.json
kubeseal < infra/secrets/raw/example-prod.json > infra/secrets/prod/sealed-example.json

# have to commit because Argo will get these from the repository
git add infra/secrets/prod/sealed-example.json -f
git add infra/secrets/dev/sealed-example.json -f
git commit -m "[auto] update sealed-secrets"
git push

##############################
# Apply Secrets Applications #
##############################

kubectl apply -f infra/secrets-dev.yaml
kubectl apply -f infra/secrets-prod.yaml

echo ""
echo "[DONE]"
echo ""
echo "Run 'kubectl port-forward service/argocd-server -n argocd 18080:443'"
echo "Then access in browser 'localhost:18080'"
echo ""

