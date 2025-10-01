#!/usr/bin/env bash
set -euo pipefail

echo -e "\033[36m╔════════════════════════════════════════════╗\033[0m"
echo -e "\033[36m║  Setup kind Cluster with Calico           ║\033[0m"
echo -e "\033[36m╚════════════════════════════════════════════╝\033[0m"
echo ""
echo "This script creates a kind (Kubernetes in Docker) cluster"
echo "with Calico for network policy enforcement."
echo ""
echo "kind works on Docker Desktop and provides full network policy support!"
echo ""

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo -e "\033[31m❌ kind is not installed\033[0m"
    echo ""
    echo "Install kind:"
    echo "  # On Linux/WSL:"
    echo "  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
    echo "  chmod +x ./kind"
    echo "  sudo mv ./kind /usr/local/bin/kind"
    echo ""
    echo "  # On macOS:"
    echo "  brew install kind"
    echo ""
    echo "  # On Windows (PowerShell):"
    echo "  curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64"
    echo "  Move-Item .\\kind-windows-amd64.exe c:\\windows\\kind.exe"
    exit 1
fi

echo "✅ kind is installed"
echo ""

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^container-security$"; then
    echo -e "\033[33m⚠️  Cluster 'container-security' already exists\033[0m"
    echo ""
    echo -n "Delete and recreate? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Deleting existing cluster..."
        kind delete cluster --name container-security
    else
        echo "Using existing cluster"
        kubectl cluster-info --context kind-container-security
        exit 0
    fi
fi

echo "[1/4] Creating kind cluster..."
cat <<EOF | kind create cluster --name container-security --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
EOF

echo ""
echo "[2/4] Installing Calico CNI..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml

echo ""
echo "[3/4] Waiting for Calico to be ready..."
kubectl wait --for=condition=available --timeout=180s deployment/calico-kube-controllers -n kube-system
kubectl wait --for=condition=ready --timeout=180s pod -l k8s-app=calico-node -n kube-system

echo ""
echo "[4/4] Verifying cluster..."
kubectl get nodes
echo ""
kubectl get pods -n kube-system | grep calico

echo ""
echo -e "\033[32m✅ kind cluster 'container-security' is ready!\033[0m"
echo ""
echo -e "\033[36mTo use this cluster:\033[0m"
echo "  kubectl config use-context kind-container-security"
echo ""
echo -e "\033[36mTo switch back to Docker Desktop:\033[0m"
echo "  kubectl config use-context docker-desktop"
echo ""
echo -e "\033[36mTo delete this cluster:\033[0m"
echo "  kind delete cluster --name container-security"