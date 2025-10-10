#!/bin/bash

# Server installation script intended to be run directly on the target server.
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
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY:-}

if [ -z "$EMAIL_ADDRESS" ]; then
  echo "❌ EMAIL_ADDRESS is required (set in environment or .env file)."
  exit 1
fi

if [ -z "$SSH_PUBLIC_KEY" ]; then
  echo "❌ SSH_PUBLIC_KEY is required (set in environment or .env file)."
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

echo "📦 Preparing base system packages..."
${SUDO} apt-get update -y
${SUDO} apt-get install -y curl tar gzip ufw fail2ban neovim

echo ""
echo "🛡️ Hardening SSH configuration..."
SSHD_CONFIG="/etc/ssh/sshd_config"
${SUDO} cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%s)"
${SUDO} sed -i \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
  -e 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' \
  -e 's/^#\?UsePAM.*/UsePAM no/' \
  "$SSHD_CONFIG"
SSH_CONFIG="/etc/ssh/ssh_config"
if [ -f "$SSH_CONFIG" ]; then
  ${SUDO} cp "$SSH_CONFIG" "${SSH_CONFIG}.bak.$(date +%s)"
  ${SUDO} sed -i \
    -e 's/^#\?[[:space:]]*PasswordAuthentication.*/PasswordAuthentication no/' \
    -e 's/^#\?[[:space:]]*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' \
    "$SSH_CONFIG"
fi
if [ -f "$SSH_CONFIG" ] && ! ${SUDO} grep -q '^PasswordAuthentication' "$SSH_CONFIG"; then
  echo "PasswordAuthentication no" | ${SUDO} tee -a "$SSH_CONFIG" >/dev/null
fi
if [ -f "$SSH_CONFIG" ] && ! ${SUDO} grep -q '^ChallengeResponseAuthentication' "$SSH_CONFIG"; then
  echo "ChallengeResponseAuthentication no" | ${SUDO} tee -a "$SSH_CONFIG" >/dev/null
fi
if [ -n "$SUDO" ]; then
  TARGET_HOME=$(${SUDO} sh -c 'echo -n "$HOME"')
else
  TARGET_HOME="$HOME"
fi
SSH_DIR="$TARGET_HOME/.ssh"
AUTH_KEYS_FILE="$SSH_DIR/authorized_keys"
${SUDO} mkdir -p "$SSH_DIR"
${SUDO} chmod 700 "$SSH_DIR"
if ! ${SUDO} test -f "$AUTH_KEYS_FILE"; then
  ${SUDO} touch "$AUTH_KEYS_FILE"
fi
if ! ${SUDO} grep -qxF "$SSH_PUBLIC_KEY" "$AUTH_KEYS_FILE"; then
  echo "$SSH_PUBLIC_KEY" | ${SUDO} tee -a "$AUTH_KEYS_FILE" >/dev/null
fi
${SUDO} chmod 600 "$AUTH_KEYS_FILE"
${SUDO} systemctl reload sshd || {
  echo "❌ Failed to reload sshd. Aborting."
  exit 1
}

echo ""
echo "🚧 Configuring firewall with UFW..."
${SUDO} ufw --force reset
${SUDO} ufw default deny incoming
${SUDO} ufw default allow outgoing
${SUDO} ufw allow 22/tcp comment 'Open SSH access'
${SUDO} ufw allow 80/tcp comment 'HTTP ingress'
${SUDO} ufw allow 443/tcp comment 'HTTPS ingress'
${SUDO} ufw allow in on lo to any port 6443 comment 'k3s API local access'
${SUDO} ufw deny 6443/tcp comment 'Block external k3s API access'
${SUDO} ufw deny out 22/tcp comment 'Block outbound SSH scans'
${SUDO} ufw --force enable

echo ""
echo "👮 Enabling fail2ban protection..."
${SUDO} systemctl enable --now fail2ban

echo ""
echo "🚀 Installing K3s with Traefik disabled..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" ${SUDO} sh -

KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
${SUDO} chmod 644 "$KUBECONFIG_PATH"
export KUBECONFIG="$KUBECONFIG_PATH"

echo "🔍 Verifying K3s installation..."
kubectl get nodes
echo ""

echo "📦 Installing Helm package manager..."
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

echo ""
echo "🧹 Cleaning up installer directory..."
${SUDO} rm -rf "$SCRIPT_DIR"
