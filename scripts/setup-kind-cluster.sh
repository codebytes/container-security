#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Setup a kind (Kubernetes IN Docker) cluster with Calico for the
# container-security demos.
#
# Why kind + Calico?
#   Demo 5 (zero-trust networking) needs a NetworkPolicy-ENFORCING CNI. The
#   default CNIs used by Docker Desktop's built-in Kubernetes (kubeadm/kindnet)
#   accept NetworkPolicy objects but do NOT enforce them, so the demo "fails
#   open". Calico enforces them for real.
#
# Docker Desktop note (macOS/Windows):
#   This script uses the standalone `kind` CLI, which works regardless of the
#   image store. If instead you use Docker Desktop's BUILT-IN kind provisioner,
#   you must enable the containerd image store
#   (Settings → General → "Use containerd for pulling and storing images").
#   Requires Docker Desktop 4.51+.
#
# kind version:
#   Use kind >= v0.27.0. On v0.27.0+ the containerd registry-mirror config patch
#   is no longer strictly required, but we still write the per-node certs.d
#   `hosts.toml` alias (the durable mechanism) so `localhost:5000` resolves from
#   inside the cluster.
#
# Architecture:
#   This script is arch-agnostic and runs on macOS arm64/amd64 and Windows
#   amd64/arm64. We intentionally do NOT pass `--image kindest/node:...` so kind
#   uses its default node image for the installed kind binary (a multi-arch tag
#   resolved per host arch). If you ever pin a node image, pin a multi-arch TAG
#   (e.g. kindest/node:v1.31.0), never a single-arch sha256 digest. Calico
#   v3.32.0 images and registry:2 are multi-arch (amd64+arm64), so nothing here
#   hardcodes an architecture.
# ─────────────────────────────────────────────────────────────────────────────

CLUSTER_NAME="container-security"
CALICO_VERSION="v3.32.0"
KIND_NETWORK="kind"

# Local registry (shared with demo 2 supply-chain pipeline). Host port 5000 and
# container name `registry` are chosen to match demo 2's image refs
# (localhost:5000/guardian-demo-app) and cosign/Kyverno configuration.
REG_NAME="registry"
REG_PORT="5000"

FORCE=0

usage() {
    cat <<USAGE
Usage: $0 [--force] [--help]

Creates a kind cluster named '${CLUSTER_NAME}' with Calico ${CALICO_VERSION} and
wires a local registry (localhost:${REG_PORT}) into the kind network so locally
built/signed images (e.g. demo 2's localhost:${REG_PORT}/guardian-demo-app) pull
at admission.

Options:
  --force    Delete and recreate the cluster without prompting (CI-friendly).
  --help     Show this help and exit.
USAGE
}

for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=1 ;;
        --help|-h)  usage; exit 0 ;;
        *) echo "Unknown argument: $arg" >&2; usage; exit 1 ;;
    esac
done

echo -e "\033[36m╔════════════════════════════════════════════╗\033[0m"
echo -e "\033[36m║  Setup kind Cluster with Calico           ║\033[0m"
echo -e "\033[36m╚════════════════════════════════════════════╝\033[0m"
echo ""
echo "This script creates a kind (Kubernetes in Docker) cluster"
echo "with Calico ${CALICO_VERSION} for network policy enforcement,"
echo "and a local registry on localhost:${REG_PORT} wired into the kind network."
echo ""

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo -e "\033[31m❌ kind is not installed\033[0m"
    echo ""
    echo "Install kind (>= v0.27.0):"
    echo "  # On macOS:"
    echo "  brew install kind"
    echo ""
    echo "  # On Linux/WSL:"
    echo "  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64"
    echo "  chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind"
    echo ""
    echo "  # On Windows (PowerShell):"
    echo "  curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.27.0/kind-windows-amd64"
    echo "  Move-Item .\\kind-windows-amd64.exe c:\\windows\\kind.exe"
    exit 1
fi

echo "✅ kind is installed"
echo ""

# ── Step 1: Local registry container (idempotent) ───────────────────────────
# Start a registry on the host (localhost:5000) and connect it to the kind
# docker network so cluster nodes can pull from it as ${REG_NAME}:5000.
echo "[1/6] Ensuring local registry container '${REG_NAME}' on localhost:${REG_PORT}..."
if [ "$(docker inspect -f '{{.State.Running}}' "${REG_NAME}" 2>/dev/null || true)" != 'true' ]; then
    docker run -d --restart=always -p "127.0.0.1:${REG_PORT}:5000" --name "${REG_NAME}" registry:2 >/dev/null
    echo "✅ Local registry started"
else
    echo "✅ Local registry already running"
fi
echo ""

# ── Step 2: Create kind cluster (idempotent) ────────────────────────────────
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "\033[33m⚠️  Cluster '${CLUSTER_NAME}' already exists\033[0m"
    if [ "$FORCE" -eq 1 ]; then
        echo "Deleting existing cluster (--force)..."
        kind delete cluster --name "${CLUSTER_NAME}"
    else
        echo ""
        echo -n "Delete and recreate? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "Deleting existing cluster..."
            kind delete cluster --name "${CLUSTER_NAME}"
        else
            echo "Using existing cluster"
            kubectl cluster-info --context "kind-${CLUSTER_NAME}" || true
            # Still ensure registry wiring + ConfigMap are in place, then exit.
            connect_registry() {
                if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.'"${KIND_NETWORK}"'}}' "${REG_NAME}" 2>/dev/null)" = 'null' ]; then
                    docker network connect "${KIND_NETWORK}" "${REG_NAME}" || true
                fi
            }
            connect_registry
            exit 0
        fi
    fi
fi

echo "[2/6] Creating kind cluster '${CLUSTER_NAME}'..."
cat <<EOF | kind create cluster --name "${CLUSTER_NAME}" --config=-
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
EOF
echo ""

# ── Step 3: Install Calico (raw manifest, pinned) ───────────────────────────
echo "[3/6] Installing Calico ${CALICO_VERSION} CNI..."
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"
echo ""

echo "[4/6] Waiting for Calico and nodes to be ready..."
kubectl wait --for=condition=available --timeout=180s deployment/calico-kube-controllers -n kube-system
kubectl wait --for=condition=ready --timeout=180s pod -l k8s-app=calico-node -n kube-system
kubectl wait --for=condition=Ready nodes --all --timeout=180s
echo ""

# ── Step 5: Wire the registry into the kind network + per-node config ────────
# Official kind "local registry" pattern:
#   https://kind.sigs.k8s.io/docs/user/local-registry/
echo "[5/6] Wiring local registry into the kind network..."
# Add certs.d aliases so containerd can pull over plain HTTP from BOTH names:
#   - localhost:${REG_PORT}  : the host-facing name used by docs / kind convention
#   - ${REG_NAME}:${REG_PORT}: the IN-CLUSTER name demo 2 manifests reference
#     (registry:5000). Without the registry:5000 alias, an admitted signed pod
#     fails to pull (`ImagePullBackOff`: "HTTP response to HTTPS client").
for node in $(kind get nodes --name "${CLUSTER_NAME}"); do
    for reg_host in "localhost:${REG_PORT}" "${REG_NAME}:${REG_PORT}"; do
        node_dir="/etc/containerd/certs.d/${reg_host}"
        docker exec "${node}" mkdir -p "${node_dir}"
        cat <<HOSTS | docker exec -i "${node}" cp /dev/stdin "${node_dir}/hosts.toml"
[host."http://${REG_NAME}:5000"]
HOSTS
    done
done

# Connect registry to the kind network if not already connected
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.'"${KIND_NETWORK}"'}}' "${REG_NAME}" 2>/dev/null)" = 'null' ]; then
    docker network connect "${KIND_NETWORK}" "${REG_NAME}"
fi

# Document the local registry per the KEP-1755 convention
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
echo "✅ Registry reachable from host (localhost/127.0.0.1:${REG_PORT}) AND in-cluster as registry:${REG_PORT}"
echo ""

# ── Step 6: Verify ──────────────────────────────────────────────────────────
echo "[6/6] Verifying cluster..."
kubectl get nodes
echo ""
kubectl get pods -n kube-system | grep calico || true

echo ""
echo -e "\033[32m✅ kind cluster '${CLUSTER_NAME}' is ready!\033[0m"
echo ""
echo -e "\033[36mTo use this cluster:\033[0m"
echo "  kubectl config use-context kind-${CLUSTER_NAME}"
echo ""
echo -e "\033[36mPush demo images so the cluster can pull them:\033[0m"
echo "  docker tag <image> localhost:${REG_PORT}/<image> && docker push localhost:${REG_PORT}/<image>"
echo ""
echo -e "\033[36mTo switch back to Docker Desktop:\033[0m"
echo "  kubectl config use-context docker-desktop"
echo ""
echo -e "\033[36mTo delete this cluster:\033[0m"
echo "  kind delete cluster --name ${CLUSTER_NAME}"
