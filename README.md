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

### 🔧 Additional Tools

- **Docker** - Container runtime
- **kubectl** - Kubernetes CLI
- **Minikube** - Local Kubernetes cluster
- **ArgoCD** - GitOps continuous delivery tool

## 📁 Project Structure

```
├── main.go
├── dockerfile
├── README.md
└── k8s/
    ├── deployment.yaml
    └── service.yaml
```

## ⚡ Quick Start

### 1️⃣ Go Server Deployment 🌐

1. **Clone and navigate to the repository**

   ```bash
   git clone <repository-url>
   cd cicd
   ```

2. **Start local Kubernetes cluster**

   ```bash
   minikube start
   ```

3. **Build Docker image**

   ```bash
   # Switch to Minikube's Docker daemon to build image directly in cluster
   eval $(minikube docker-env)
   docker build -t go-server:latest .
   ```

4. **Deploy to Kubernetes**

   ```bash
   kubectl apply -f k8s/deployment.yaml
   kubectl apply -f k8s/service.yaml
   ```

5. **Verify deployment**

   ```bash
   kubectl get pods
   kubectl get services
   ```

6. **Access the application locally**

   ```bash
   # Get pod name
   kubectl get pods

   # Port forward to access locally
   kubectl port-forward pod/<pod-name> 8080:8080
   ```

   Visit `http://localhost:8080` to see the "Hello from Go server!" message.

### 2️⃣ ArgoCD Setup 🚀

1. **Install ArgoCD**

   ```bash
   # Create namespace
   kubectl create namespace argocd

   # Install ArgoCD
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

2. **Verify ArgoCD installation**

   ```bash
   kubectl get pods -n argocd
   ```

3. **Access ArgoCD UI**

   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

   Visit `https://localhost:8080` to access ArgoCD dashboard. 🎛️

4. **Get initial admin password**

   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

5. **Create ArgoCD Application**

   **Via ArgoCD UI:**

   - Click "**+ NEW APP**"
   - **Application Name**: `go-server-app`
   - **Repository URL**: `git://<your-ip-address>/cicd`
   - **Path**: `./k8s`
   - **Destination**: `https://kubernetes.default.svc` / `default` namespace

### 3️⃣ Local Git Repository Setup (Optional) 🌳

For development without pushing to remote repositories:

1. **Start Git daemon (run from parent directory)**

   ```bash
   cd ..
   git daemon --reuseaddr --base-path=. --export-all --verbose
   ```

2. **Repository access**
   - Repository URL: `git://<your-ip-address>/cicd`
   - Test with: `git clone git://<your-ip-address>/cicd`
