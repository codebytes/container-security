#!/bin/bash
# Supply Chain Trust Demo - Cleanup Script
# Removes local registry and generated artifacts

set -e

# Resolve paths relative to this script's demo root so cleanup works regardless
# of the caller's CWD (the README documents running it from the demo root).
script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(dirname "$script_dir")"
cd "$project_root"

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN}🧹 Supply Chain Trust Demo - Cleanup${NC}"
echo -e "${CYAN}======================================${NC}"
echo "Removing demo-2-specific artifacts and images"
echo ""

echo -e "${CYAN}[1/3] Removing generated artifacts${NC}"
rm -rf artifacts/*.json artifacts/*.txt artifacts/*.spdx 2>/dev/null || true
echo "✅ Artifacts cleaned"

echo -e "${CYAN}[2/3] Removing in-cluster admission resources${NC}"
if command -v kubectl >/dev/null 2>&1; then
    kubectl delete -f manifests/deploy-unsigned.yaml --ignore-not-found >/dev/null 2>&1 || true
    kubectl delete -f manifests/deploy-signed.yaml --ignore-not-found >/dev/null 2>&1 || true
    kubectl delete -f manifests/policy-require-signature.yaml --ignore-not-found >/dev/null 2>&1 || true
    kubectl delete clusterpolicy verify-supply-chain-signatures --ignore-not-found >/dev/null 2>&1 || true
    kubectl delete -f manifests/demo-namespace.yaml --ignore-not-found >/dev/null 2>&1 || true
    kubectl delete namespace demo-gamora --ignore-not-found >/dev/null 2>&1 || true
    kubectl -n kyverno delete secret guardian-cosign-pub --ignore-not-found >/dev/null 2>&1 || true
    echo "✅ Namespace, ClusterPolicy, and cosign public-key secret removed"
else
    echo "ℹ️  kubectl not found — skipping in-cluster cleanup (nothing to remove or no cluster)."
fi

echo -e "${CYAN}[3/3] Removing demo images${NC}"
for reg in localhost:5000 127.0.0.1:5000 registry:5000; do
    docker rmi "${reg}/guardian-demo-app:v0.1.0-secure" 2>/dev/null || true
    docker rmi "${reg}/guardian-demo-app:v0.1.0-unsigned" 2>/dev/null || true
done
docker rmi guardian-demo-app:v0.1.0-secure 2>/dev/null || true
echo "✅ Demo images removed"

echo ""
echo -e "${GREEN}✅ Cleanup completed successfully!${NC}"
echo ""
echo "Removed resources:"
echo "• Generated SBOMs and scan reports"
echo "• demo-gamora namespace, verify-supply-chain-signatures ClusterPolicy, guardian-cosign-pub secret"
echo "• Demo container images"
echo ""
echo -e "${YELLOW}Note:${NC} Cosign keypair files in the demo root are preserved for reuse"
echo -e "${YELLOW}Note:${NC} The shared 'registry' container and kind cluster are NOT removed here;"
echo "      tear those down with scripts/teardown-kind-cluster.sh"
