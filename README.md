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
- **Multipass** ([Install Guide](https://multipass.run/install)) - Ubuntu VM manager for Linux/macOS/Windows
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

### 🖥️ VM & K3s Setup

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
         server: https://<VM-IP-ADDRESS>:6443      ←✅ Replace with your VM IP
         insecure-skip-tls-verify: true            ←✅ Add this line
   ```

7. **Verify connection**
   ```bash
   kubectl get nodes
   ```
   You should see your K3s node listed as "Ready".

### 1️⃣ Go Server Deployment 🌐

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
   kubectl apply -f kube/server-go.yaml
   ```

4. **Verify deployment**

   ```bash
   # Check deployment status
   kubectl get deployments
   kubectl get pods
   kubectl get services

   # Get the NodePort for external access
   kubectl get svc go-server -o wide
   ```

5. **Access the application**
   Visit `http://<VM-IP-ADDRESS>:<nodeport>` to see the "Hello from Go server!" message.

   The NodePort will be displayed in the previous command output.

### 2️⃣ ArgoCD Setup 🚀

1. Helm install

```bash
   helm repo add argo https://argoproj.github.io/argo-helm
   helm repo updatekubectl create namespace argocd
```

1. **Install ArgoCD**

   ```bash
   # Create namespace
   kubectl create namespace argocd

   # Install
   helm install argocd argo/argo-cd -n argocd
   ```

2. **Verify ArgoCD installation**

   ```bash
   # Get initial password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

   # Port forward to localhost
   kubectl port-forward service/argocd-server -n argocd 8080:443
   ```

   Visit `http://localhost:8080` to access ArgoCD dashboard.

   - Username: `admin`
   - Password: <initial-password>

   **Note:** You may need to accept the security warning due to the self-signed certificate.

3. **Create ArgoCD Application**

   **Via ArgoCD UI:**

   - Click "**+ NEW APP**"
   - **Application Name**: `go-server-app`
   - **Repository URL**: `<repo-url>`
   - **Path**: `./kube`
   - **Destination**: `https://kubernetes.default.svc` / `default` namespace

### 3️⃣ Local Git Repository Setup (Optional) 🌳

For development without pushing to remote repositories:

1. **Start Git daemon (run from parent directory)**

   ```bash
   cd ..
   git daemon --reuseaddr --base-path=. --export-all --verbose
   ```

2. **Repository access**
   - Repository URL: `git://<ip-address>/cicd`
   - Test with: `git clone git://<ip-address>/cicd`
