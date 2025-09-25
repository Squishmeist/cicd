#!/bin/bash

# K3s Installation Script for Remote Server
# This script installs K3s with Traefik ingress controller on a remote Ubuntu server

set -e  # Exit on any error

# Load environment variables from .env file
if [ -f ".env" ]; then
    source .env
    echo "✅ Loaded environment variables from .env"
else
    echo "❌ .env file not found! Please create it first."
    echo "💡 Use .env.example as a template"
    exit 1
fi

# Check if required variables are set
if [ -z "$SERVER_IP" ] || [ -z "$EMAIL_ADDRESS" ]; then
    echo "❌ Missing required environment variables!"
    echo "Please ensure the following are set in your .env file:"
    echo "  - SERVER_IP"
    echo "  - EMAIL_ADDRESS (for ACME certificates)"
    exit 1
fi

echo "🚀 Setting up K3s on remote server: $SERVER_IP"
echo "📧 Using email for ACME certificates: $EMAIL_ADDRESS"
echo ""

echo "🔧 Installing K3s with default settings..."
curl -sfL https://get.k3s.io | sh -

echo "✅ K3s installation completed!"
echo ""

echo "� Setting up kubectl configuration..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

echo "🔍 Verifying K3s installation..."
kubectl get nodes
echo ""

echo "�📦 Installing Helm package manager..."
sudo apt-get install curl gpg apt-transport-https --yes
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

echo "✅ Helm installation completed!"
echo ""

echo "🌐 Adding Traefik Helm repository..."
helm repo add traefik https://helm.traefik.io/traefik
helm repo update

echo ""
echo "🚀 Installing Traefik ingress controller..."
echo ""

helm upgrade --install traefik traefik/traefik \
   --namespace kube-system \
   --create-namespace \
   --set ingressClass.enabled=true \
   --set service.type=LoadBalancer \
   --set additionalArguments[0]="--certificatesresolvers.default.acme.email=$EMAIL_ADDRESS" \
   --set additionalArguments[1]="--certificatesresolvers.default.acme.storage=/data/acme.json" \
   --set additionalArguments[2]="--certificatesresolvers.default.acme.httpchallenge.entrypoint=web"

echo ""
echo "✅ Traefik installation completed!"

echo ""
echo "🎉 K3s setup completed successfully!"
echo ""