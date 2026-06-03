#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Tear down the shared container-security demo cluster.
#
# This is the counterpart to scripts/setup-kind-cluster.sh. Because the kind
# nodes are containers, deleting the cluster removes ALL demo workloads and
# namespaces in one shot — individual demos do NOT need their own teardown.
#
# It also removes the shared local registry (registry:2 on host port 5000) that
# setup wired into the `kind` docker network, and cleans up the `kind` network if
# nothing else is using it.
#
# Safe to run repeatedly: no errors if the cluster/registry are already gone.
# ─────────────────────────────────────────────────────────────────────────────

CLUSTER_NAME="container-security"
KIND_NETWORK="kind"
REG_NAME="registry"

FORCE=0

usage() {
    cat <<USAGE
Usage: $0 [--force] [--help]

Deletes the kind cluster '${CLUSTER_NAME}', removes the shared local registry
container '${REG_NAME}', and cleans up the '${KIND_NETWORK}' docker network if unused.

Options:
  --force    Skip the confirmation prompt (CI-friendly).
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
echo -e "\033[36m║  Teardown kind Cluster + Registry         ║\033[0m"
echo -e "\033[36m╚════════════════════════════════════════════╝\033[0m"
echo ""
echo "This will remove:"
echo "  • kind cluster '${CLUSTER_NAME}' (and all demo workloads/namespaces)"
echo "  • local registry container '${REG_NAME}'"
echo "  • the '${KIND_NETWORK}' docker network (only if unused)"
echo ""

if [ "$FORCE" -ne 1 ]; then
    echo -n "Proceed with teardown? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# ── Step 1: Delete the kind cluster (idempotent) ────────────────────────────
echo ""
echo "[1/3] Deleting kind cluster '${CLUSTER_NAME}'..."
if command -v kind &> /dev/null && kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    kind delete cluster --name "${CLUSTER_NAME}"
    echo "✅ Cluster deleted"
else
    echo "✅ Cluster '${CLUSTER_NAME}' not present (nothing to delete)"
fi
echo ""

# ── Step 2: Stop and remove the shared registry (idempotent) ────────────────
echo "[2/3] Removing local registry container '${REG_NAME}'..."
if [ -n "$(docker ps -aq -f "name=^${REG_NAME}$" 2>/dev/null)" ]; then
    docker rm -f "${REG_NAME}" >/dev/null 2>&1 || true
    echo "✅ Registry container removed"
else
    echo "✅ Registry container not present (nothing to remove)"
fi
echo ""

# ── Step 3: Clean up the kind docker network if unused ──────────────────────
echo "[3/3] Cleaning up the '${KIND_NETWORK}' docker network (if unused)..."
if docker network inspect "${KIND_NETWORK}" >/dev/null 2>&1; then
    # Count containers still attached to the network
    attached="$(docker network inspect "${KIND_NETWORK}" -f '{{len .Containers}}' 2>/dev/null || echo "0")"
    if [ "${attached}" = "0" ]; then
        docker network rm "${KIND_NETWORK}" >/dev/null 2>&1 && echo "✅ Network '${KIND_NETWORK}' removed" \
            || echo "ℹ️  Network '${KIND_NETWORK}' could not be removed (may be managed by kind)"
    else
        echo "ℹ️  Network '${KIND_NETWORK}' still has ${attached} attached container(s); leaving it in place"
    fi
else
    echo "✅ Network '${KIND_NETWORK}' not present (nothing to clean up)"
fi

echo ""
echo -e "\033[32m✅ Teardown complete.\033[0m"
echo ""
echo "To recreate the cluster:"
echo "  ./scripts/setup-kind-cluster.sh"
