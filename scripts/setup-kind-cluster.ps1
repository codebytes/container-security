#requires -Version 7.0
<#
.SYNOPSIS
    Setup a kind (Kubernetes IN Docker) cluster with Calico for the
    container-security demos (PowerShell twin of setup-kind-cluster.sh).

.DESCRIPTION
    Demo 5 (zero-trust networking) needs a NetworkPolicy-ENFORCING CNI. The
    default CNIs used by Docker Desktop's built-in Kubernetes (kubeadm/kindnet)
    accept NetworkPolicy objects but do NOT enforce them, so the demo "fails
    open". Calico enforces them for real.

    Docker Desktop note: this script uses the standalone `kind` CLI, which works
    regardless of the image store. If you instead use Docker Desktop's BUILT-IN
    kind provisioner, enable the containerd image store
    (Settings -> General -> "Use containerd for pulling and storing images").
    Requires Docker Desktop 4.51+.

    kind version: use kind >= v0.27.0. The per-node certs.d `hosts.toml` alias is
    written so localhost:5000 resolves from inside the cluster.

    Architecture: this script is arch-agnostic and runs on macOS arm64/amd64 and
    Windows amd64/arm64. We intentionally do NOT pass `--image kindest/node:...`
    so kind uses its default (multi-arch) node image for the installed kind
    binary. If you ever pin a node image, pin a multi-arch TAG, never a
    single-arch sha256 digest. Calico v3.32.0 images and registry:2 are
    multi-arch, so nothing here hardcodes an architecture.

.PARAMETER Force
    Delete and recreate the cluster without prompting (CI-friendly).
#>
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$ClusterName   = "container-security"
$CalicoVersion = "v3.32.0"
$KindNetwork   = "kind"

# Local registry (shared with demo 2 supply-chain pipeline). Host port 5000 and
# container name `registry` match demo 2's image refs
# (localhost:5000/guardian-demo-app) and cosign/Kyverno configuration.
$RegName = "registry"
$RegPort = "5000"

function Write-Header {
    Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Setup kind Cluster with Calico           ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
}

Write-Header
Write-Host ""
Write-Host "This script creates a kind cluster with Calico $CalicoVersion for network"
Write-Host "policy enforcement, and a local registry on localhost:$RegPort wired into"
Write-Host "the kind network."
Write-Host ""

# Check if kind is installed
if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
    Write-Host "❌ kind is not installed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install kind (>= v0.27.0):"
    Write-Host "  # On Windows (PowerShell):"
    Write-Host "  curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.27.0/kind-windows-amd64"
    Write-Host "  Move-Item .\kind-windows-amd64.exe c:\windows\kind.exe"
    Write-Host ""
    Write-Host "  # On macOS: brew install kind"
    exit 1
}

Write-Host "✅ kind is installed" -ForegroundColor Green
Write-Host ""

# ── Step 1: Local registry container (idempotent) ───────────────────────────
Write-Host "[1/6] Ensuring local registry container '$RegName' on localhost:$RegPort..." -ForegroundColor Cyan
$regRunning = (docker inspect -f '{{.State.Running}}' $RegName 2>$null)
if ($regRunning -ne 'true') {
    docker run -d --restart=always -p "127.0.0.1:${RegPort}:5000" --name $RegName registry:2 | Out-Null
    Write-Host "✅ Local registry started" -ForegroundColor Green
} else {
    Write-Host "✅ Local registry already running" -ForegroundColor Green
}
Write-Host ""

function Connect-Registry {
    $net = (docker inspect -f "{{json .NetworkSettings.Networks.$KindNetwork}}" $RegName 2>$null)
    if ($net -eq 'null' -or [string]::IsNullOrWhiteSpace($net)) {
        docker network connect $KindNetwork $RegName 2>$null | Out-Null
    }
}

# ── Step 2: Create kind cluster (idempotent) ────────────────────────────────
$existing = (kind get clusters 2>$null) | Select-String -Pattern "^$ClusterName$"
if ($existing) {
    Write-Host "⚠️  Cluster '$ClusterName' already exists" -ForegroundColor Yellow
    $recreate = $false
    if ($Force) {
        Write-Host "Deleting existing cluster (--Force)..."
        $recreate = $true
    } else {
        $response = Read-Host "Delete and recreate? (y/N)"
        if ($response -match '^[Yy]$') { $recreate = $true }
    }
    if ($recreate) {
        kind delete cluster --name $ClusterName
    } else {
        Write-Host "Using existing cluster"
        kubectl cluster-info --context "kind-$ClusterName" 2>$null
        Connect-Registry
        exit 0
    }
}

Write-Host "[2/6] Creating kind cluster '$ClusterName'..." -ForegroundColor Cyan
$kindConfig = @"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
nodes:
- role: control-plane
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
"@
$kindConfig | kind create cluster --name $ClusterName --config=-
Write-Host ""

# ── Step 3: Install Calico (raw manifest, pinned) ───────────────────────────
Write-Host "[3/6] Installing Calico $CalicoVersion CNI..." -ForegroundColor Cyan
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/$CalicoVersion/manifests/calico.yaml"
Write-Host ""

Write-Host "[4/6] Waiting for Calico and nodes to be ready..." -ForegroundColor Cyan
kubectl wait --for=condition=available --timeout=180s deployment/calico-kube-controllers -n kube-system
kubectl wait --for=condition=ready --timeout=180s pod -l k8s-app=calico-node -n kube-system
kubectl wait --for=condition=Ready nodes --all --timeout=180s
Write-Host ""

# ── Step 5: Wire the registry into the kind network + per-node config ────────
# Official kind "local registry" pattern:
#   https://kind.sigs.k8s.io/docs/user/local-registry/
Write-Host "[5/6] Wiring local registry into the kind network..." -ForegroundColor Cyan
# Add certs.d aliases so containerd can pull over plain HTTP from BOTH names:
#   - localhost:$RegPort   : host-facing name used by docs / kind convention
#   - ${RegName}:$RegPort  : the IN-CLUSTER name demo 2 manifests reference
#     (registry:5000). Without it, an admitted signed pod fails to pull
#     (ImagePullBackOff: "HTTP response to HTTPS client").
$hostsToml = "[host.`"http://${RegName}:5000`"]"
foreach ($node in (kind get nodes --name $ClusterName)) {
    foreach ($regHost in @("localhost:$RegPort", "${RegName}:$RegPort")) {
        $nodeDir = "/etc/containerd/certs.d/$regHost"
        docker exec $node mkdir -p $nodeDir
        $hostsToml | docker exec -i $node cp /dev/stdin "$nodeDir/hosts.toml"
    }
}

Connect-Registry

# Document the local registry per the KEP-1755 convention
$cm = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:$RegPort"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
"@
$cm | kubectl apply -f -
Write-Host "✅ Registry reachable from host (localhost/127.0.0.1:$RegPort) AND in-cluster as registry:$RegPort" -ForegroundColor Green
Write-Host ""

# ── Step 6: Verify ──────────────────────────────────────────────────────────
Write-Host "[6/6] Verifying cluster..." -ForegroundColor Cyan
kubectl get nodes
Write-Host ""
kubectl get pods -n kube-system | Select-String -Pattern 'calico'

Write-Host ""
Write-Host "✅ kind cluster '$ClusterName' is ready!" -ForegroundColor Green
Write-Host ""
Write-Host "To use this cluster:" -ForegroundColor Cyan
Write-Host "  kubectl config use-context kind-$ClusterName"
Write-Host ""
Write-Host "Push demo images so the cluster can pull them:" -ForegroundColor Cyan
Write-Host "  docker tag <image> localhost:$RegPort/<image>; docker push localhost:$RegPort/<image>"
Write-Host ""
Write-Host "To switch back to Docker Desktop:" -ForegroundColor Cyan
Write-Host "  kubectl config use-context docker-desktop"
Write-Host ""
Write-Host "To delete this cluster:" -ForegroundColor Cyan
Write-Host "  kind delete cluster --name $ClusterName"
