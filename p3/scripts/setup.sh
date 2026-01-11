#!/bin/bash

# **Workflow**:
# 1. Creates k3d cluster
# 2. Deploys ArgoCD via official manifest
# 3. Waits for ArgoCD pods to be ready (timeout: 600s)
# 4. Configures ArgoCD sync interval to 30 seconds
# 5. Retrieves initial admin password from secret
# 6. Installs ArgoCD CLI
# 7. Port-forwards ArgoCD server to localhost:8080
# 8. Logs in to ArgoCD
# 9. Changes admin password to `admin123`
# 10. Creates dev namespace
# 11. Applies application manifests

set -e

NAMESPACE_ARGOCD="argocd"
NAMESPACE_DEV="dev"

# Create k3d cluster
echo "Creating k3d cluster..."
k3d cluster create mycluster --servers 1

# Install ArgoCD
echo "ArgoCD installing..."
kubectl create namespace $NAMESPACE_ARGOCD
kubectl apply -n $NAMESPACE_ARGOCD -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD deployment
echo "Waiting for ArgoCD pods..."
kubectl wait --for=condition=Available --timeout=600s deployment -l app.kubernetes.io/name=argocd-server -n $NAMESPACE_ARGOCD

# Configure ArgoCD polling interval to 30 seconds
echo "Configuring ArgoCD sync interval to 30 seconds..."
kubectl patch configmap argocd-cm -n $NAMESPACE_ARGOCD --type merge -p '{"data":{"timeout.reconciliation":"30s"}}'
kubectl rollout restart deployment argocd-repo-server -n $NAMESPACE_ARGOCD
kubectl rollout restart statefulset argocd-application-controller -n $NAMESPACE_ARGOCD
kubectl rollout status deployment argocd-repo-server -n $NAMESPACE_ARGOCD --timeout=120s
kubectl rollout status statefulset argocd-application-controller -n $NAMESPACE_ARGOCD --timeout=120s

# Get ArgoCD password
echo "Getting ArgoCD password..."
ARGOCD_PWD=$(kubectl -n $NAMESPACE_ARGOCD get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD password : $ARGOCD_PWD"

# Config ArgoCD CLI
if ! command -v argocd &> /dev/null
then
    echo "Installing ArgoCD CLI..."
    curl -sSL -o argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
    chmod +x argocd-linux-amd64
    sudo mv argocd-linux-amd64 /usr/local/bin/argocd
fi

echo "ArgoCD CLI installed."

# Change ArgoCD password to admin123
echo "Changing ArgoCD password to admin123..."
kubectl port-forward svc/argocd-server --address 0.0.0.0 -n $NAMESPACE_ARGOCD 8080:443 > /dev/null 2>&1 &
PF_PID=$!
sleep 3
argocd login localhost:8080 --username admin --password $ARGOCD_PWD --insecure
argocd account update-password --account admin --current-password $ARGOCD_PWD --new-password admin123
kill $PF_PID 2>/dev/null || true
echo "Password changed to: admin123"

# Create the dev namespace
kubectl create namespace $NAMESPACE_DEV

# Apply YAML files
echo "Deployment of YAML files..."

# Get the parent folder of the script (i.e., the p3 folder)
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Apply YAML files
kubectl apply -f "$BASE_DIR/confs/deployment.yaml"
kubectl apply -f "$BASE_DIR/confs/service.yaml"
kubectl apply -f "$BASE_DIR/confs/argo-application.yaml"

echo "Everything is setup! Success!"