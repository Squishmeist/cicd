#!/bin/bash

# K3s installation script intended to be run directly on the target server.
# - Installs K3s with the bundled Traefik ingress disabled.
# - Installs Helm, Traefik (via Helm), and cert-manager with custom values.
# - Applies the ClusterIssuer manifest after templating the ACME email address.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ENV_FILE="${SCRIPT_DIR}/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  echo "✅ Loaded environment variables from .env"
else
  echo "ℹ️ No .env file found alongside script. Using existing environment variables."
fi

EMAIL_ADDRESS=${EMAIL_ADDRESS:-}

if [ -z "$EMAIL_ADDRESS" ]; then
  echo "❌ EMAIL_ADDRESS is required (set in environment or .env file)."
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/traefik-values.yaml" ] || [ ! -f "$SCRIPT_DIR/cert-manager-values.yaml" ] || [ ! -f "$SCRIPT_DIR/cluster-issuer.yaml" ] || [ ! -f "$SCRIPT_DIR/argocd-values.yaml" ] || [ ! -f "$SCRIPT_DIR/redis-values.yaml" ]; then
  echo "❌ Required manifest files not found in $SCRIPT_DIR."
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

echo "🚀 Installing K3s with Traefik disabled..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" ${SUDO} sh -

KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
${SUDO} chmod 644 "$KUBECONFIG_PATH"
export KUBECONFIG="$KUBECONFIG_PATH"

echo "🔍 Verifying K3s installation..."
kubectl get nodes
echo ""

echo "📦 Installing Helm package manager..."
${SUDO} apt-get update -y
${SUDO} apt-get install -y curl tar gzip
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm-3.sh
${SUDO} chmod +x /tmp/get-helm-3.sh
if [ -n "$SUDO" ]; then
  HELM_USE_SUDO=true
else
  HELM_USE_SUDO=false
fi
env USE_SUDO="$HELM_USE_SUDO" /tmp/get-helm-3.sh
rm -f /tmp/get-helm-3.sh

echo "✅ Helm installation completed!"
echo ""

echo "🌐 Adding Helm repositories..."
helm repo add traefik https://helm.traefik.io/traefik
helm repo add jetstack https://charts.jetstack.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

echo ""
echo "🚀 Installing Traefik ingress controller..."
helm upgrade --install traefik traefik/traefik \
  --namespace kube-system \
  --create-namespace \
  --values "$SCRIPT_DIR/traefik-values.yaml"

echo ""
echo "🔒 Installing cert-manager for SSL certificates..."
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --values "$SCRIPT_DIR/cert-manager-values.yaml"

echo ""
echo "⏳ Waiting for cert-manager to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=180s

echo ""
echo "🚀 Installing Argo CD..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values "$SCRIPT_DIR/argocd-values.yaml"

echo ""
echo "⏳ Waiting for Argo CD server to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s

echo ""
echo "🚀 Installing Redis..."
helm upgrade --install redis bitnami/redis \
  --namespace redis \
  --create-namespace \
  --values "$SCRIPT_DIR/redis-values.yaml"

echo ""
echo "⏳ Waiting for Redis master pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n redis --timeout=180s

echo ""
echo "🏷️ Applying ClusterIssuer..."
sed "s/\${EMAIL_ADDRESS}/$EMAIL_ADDRESS/g" "$SCRIPT_DIR/cluster-issuer.yaml" | kubectl apply -f -

echo ""
echo "✅ Traefik, cert-manager, Argo CD, and Redis installation completed!"
