# 🚀 CI/CD

A simple Go web server project for experimenting with CI/CD pipelines using Kubernetes and ArgoCD.

## 📋 Overview

This project demonstrates a basic DevOps workflow including:

- A simple Go HTTP server
- Docker containerization
- Kubernetes deployment
- GitOps with ArgoCD
- Local development setup

## 📦 Prerequisites

Make sure you have the following tools installed:

### ✅ Required (should already be installed)

- **Git** - A distributed version control system for tracking changes in source code.
- **Go** - The Go programming language, used for building the application.
- **Terraform** - Infrastructure as Code (IaC) tool for managing cloud resources.
- **Helm** - A Kubernetes package manager for deploying and managing applications.

### 🔧 Additional Tools

- **Docker** ([Install Guide](https://docs.docker.com/get-docker/)) - Container runtime
- **kubectl** ([Install Guide](https://kubernetes.io/docs/tasks/tools/)) - Kubernetes CLI
- **ArgoCD** - GitOps continuous delivery tool (installed via Kubernetes)

## 📁 Project Structure

```
├── main.go
├── dockerfile
├── README.md
└── kube/
    └── server-go.yaml
```

## ⚡ Quick Start

### 🌐 Remote VM Setup

#### 1.Install K3s on Remote Server

1. **SSH into your remote server**

   ```bash
   # Copy
   ssh root@<server-ip> 'mkdir -p ~/k3s-setup' rsync -av infrastructure/k3s/ infrastructure/.env root@<server-ip>:~/k3s-setup/
   # Execute
   ssh root@<server-ip> "~/k3s-setup/setup-k3s.sh"
   ```

#### 2. Configure Local Access

1. **Set Up SSH Key (optional)**

   The setup script already installs the public key you provided in `.env`. If you need to add additional keys later, follow these steps:

   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub root@<server-ip>
   ```

   This command automatically appends your public key to the `~/.ssh/authorized_keys` file on the remote server.

2. **Copy K3s config to your local machine**

   ```bash
   scp root@<server-ip>:/etc/rancher/k3s/k3s.yaml ~/.kube/server-k3s.yaml
   ```

3. **Set up SSH tunnel for secure access**

   ```bash
   # Create SSH tunnel in background (keeps running)
   ssh -f -N -L 6443:localhost:6443 root@<server-ip>
   ```

#### 3. Test Local Connection

Choose one of the following methods to use kubectl locally:

**Option A: Set as default kubeconfig**

```bash
# Backup existing config (if any)
cp ~/.kube/config ~/.kube/config.backup 2>/dev/null || true

# Set remote config as default
cp ~/.kube/server-k3s.yaml ~/.kube/config

# Test connection
kubectl get nodes
```

**Option B: Use specific kubeconfig file**

```bash
# Test with specific config file
KUBECONFIG=~/.kube/server-k3s.yaml kubectl get nodes

# Or export for current session
export KUBECONFIG=~/.kube/server-k3s.yaml
kubectl get nodes
```

### Go Server Deployment 🌐

1. **Build and push Docker image** (optional - for your own registry)

   ```bash
   docker build -t <dockerhub-username>/go-server:latest .
   docker push <dockerhub-username>/go-server:latest
   ```

2. **Deploy to Kubernetes with Helm**

   ```bash
   helm template go-server deployment/helm/server \
   --values deployment/helm/server/values-go-server.yaml |
   ssh root@<server-ip> \
   "kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml apply -f -"
   kubectl apply -f deployment/go-server
   ```

### 🔑 Redis

Redis now runs with authentication and persistence enabled. If you didn’t supply an existing secret, Helm generated one during `setup-k3s.sh`. Retrieve it with:

```bash
kubectl get secret redis -n redis -o jsonpath='{.data.redis-password}' | base64 -d
```

Store the password in a secrets manager and reference it from your application configuration or create your own secret and re-run `helm upgrade`.

### ArgoCD 🚀

1. **Apply configuration**

   Apply the manifests stored in the repo:

   ```bash
   kubectl apply -f deployment/argo
   ```

2. **Retrieve the initial admin password**

   The initial admin password is stored in a Kubernetes secret. Retrieve it with:

   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

   - Username: `admin`
   - Password: (the value returned by the command above)

   After first login, change the admin password immediately.
