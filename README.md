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

- **Git** - Version control
- **Go** - Go programming language
- **Helm** - Kubernetes package manager

### 🔧 Additional Tools

- **Docker** ([Install Guide](https://docs.docker.com/get-docker/)) - Container runtime
- **kubectl** ([Install Guide](https://kubernetes.io/docs/tasks/tools/)) - Kubernetes CLI
- **Multipass** ([Install Guide](https://multipass.run/install)) - Optional Ubuntu VM manager for Linux/macOS/Windows
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

### 🌐 Remote VM Setup (Alternative)

If you prefer to use a remote server instead of a local VM, follow these steps to set up K3s on a remote Ubuntu server.

#### 1. Install K3s on Remote Server

1. **SSH into your remote server**

   ```bash
   # Copy
   scp ./infrastructure/k3s/setup-k3s.sh root@<server-ip>:~/
   # Execute
   ssh root@<server-ip> "~/setup-k3s.sh"
   ```

#### 2. Configure Local Access

1. **Set up SSH tunnel for secure access**

   ```bash
   # Create SSH tunnel in background (keeps running)
   ssh -f -N -L 6443:localhost:6443 root@<server-ip>
   ```

2. **Copy K3s config to your local machine**

   ```bash
   scp root@<server-ip>:/etc/rancher/k3s/k3s.yaml ~/.kube/server-k3s.yaml
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

1. **Clone and navigate to the repository**

   ```bash
   git clone <repository-url>
   cd cicd
   ```

2. **Build and push Docker image** (optional - for your own registry)

   ```bash
   docker build -t <dockerhub-username>/go-server:latest .
   docker push <dockerhub-username>/go-server:latest
   ```

3. **Deploy to Kubernetes**

   ```bash
   kubectl apply -f deployment/go
   ```

4. **Verify deployment**

   ```bash
   # Check deployment status
   kubectl get deployments
   kubectl get pods
   kubectl get services
   ```

### ArgoCD Setup 🚀

1. Helm install

```bash
   helm repo add argo https://argoproj.github.io/argo-helm
```

2. **Install ArgoCD**

   ```bash
   helm install argocd argo/argo-cd --namespace argocd --create-namespace

   # Let traefik handle ingress
   helm upgrade argocd argo/argo-cd -n argocd   --set server.extraArgs[0]=--insecure

   # Apply manifest
   kubectl apply -f deployment/argo
   ```

3. **Verify ArgoCD installation**

   ```bash
   # Get initial password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

   Visit `https://<domain-name>` to access ArgoCD dashboard.

   - Username: `admin`
   - Password: <initial-password>

4. **Create ArgoCD Application**

   **Via ArgoCD UI:**

   - Click "**+ NEW APP**"
   - **Application Name**: `go-server-app`
   - **Repository URL**: `<repo-url>`
   - **Path**: `./deployment/go`
   - **Destination**: `https://kubernetes.default.svc` / `default` namespace

### 🖥️ Local VM

1. **Install Multipass** (if not already installed)

   - Visit [multipass.run](https://multipass.run/install) for installation instructions

2. **Create Ubuntu VM**

   ```bash
   multipass launch --name k3s-vm --mem 2G --disk 10G --cpus 2 20.04
   ```

3. **Install K3s inside the VM**

   ```bash
   multipass shell k3s-vm
   curl -sfL https://get.k3s.io | sh -
   sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/k3s.yaml
   sudo chown ubuntu:ubuntu /home/ubuntu/k3s.yaml
   exit
   ```

4. **Get VM IP address**

   ```bash
   multipass info k3s-vm
   ```

   Note down the IP address for the next steps.

5. **Transfer kubeconfig to your local machine**

   ```bash
   multipass transfer k3s-vm:/home/ubuntu/k3s.yaml ~/.kube/config
   ```

6. **Edit kubeconfig for remote access**
   Open `~/.kube/config` and modify the cluster configuration:

   ```yaml
   clusters:
     - cluster:
         # certificate-authority-data: LS0tL...    ←❌ Remove this line
         server: https://<vm-ip>:6443      ←✅ Replace with your VM IP
         insecure-skip-tls-verify: true            ←✅ Add this line
   ```

7. **Verify connection**
   ```bash
   kubectl get nodes
   ```
   You should see your K3s node listed as "Ready".

### Local Git Repository Setup (Optional) 🌳

For development without pushing to remote repositories:

1. **Start Git daemon (run from parent directory)**

   ```bash
   cd ..
   git daemon --reuseaddr --base-path=. --export-all --verbose
   ```

2. **Repository access**
   - Repository URL: `git://<ip-address>/cicd`
   - Test with: `git clone git://<ip-address>/cicd`
