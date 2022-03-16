#!/usr/bin/env bash

needed_tools=()

if ! [ -x "$(command -v k3d)" ]; then
  needed_tools+=("k3d")
fi
if ! [ -x "$(command -v kubectl)" ]; then
  needed_tools+=("kubectl")
fi
if ! [ -x "$(command -v docker)" ]; then
  needed_tools+=("docker")
fi
if ! [ -x "$(command -v helm)" ]; then
  needed_tools+=("helm")
fi

if [ ${#needed_tools[@]} != "0" ]; then
  echo "The following tools are missing:"
  for item in "${needed_tools[@]}"; do
    echo "$item"
  done
  exit 1
fi

k3d cluster create --config k3d.yaml
kubectl config use-context k3d-argo-cd-poc
kubectl create namespace dev
kubectl create namespace argocd

docker build -t localhost:5000/example/app ./common-src
docker image push localhost:5000/example/app

helm repo add argo https://argoproj.github.io/argo-helm
echo "installing.."
helm install argocd argo/argo-cd -n argocd -f infra/argo-cd.yaml --wait --timeout 8m0s

kubectl -n argocd delete secret argocd-initial-admin-secret --ignore-not-found=true
# is 1234
kubectl -n argocd patch secret argocd-secret -p '{"stringData": {"admin.password": "$2a$12$lsj.ZMc45C3g3zDwF1E4nufjDE8LsmT/8wBBP0WORi0TcAeQ.1Wje"}}'

echo ""
echo "[DONE]"
echo ""
echo "Run 'kubectl port-forward service/argocd-server -n argocd 18080:443'"
echo "Then access in browser 'localhost:18080'"
echo ""

