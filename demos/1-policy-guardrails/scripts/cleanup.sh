#!/bin/bash
# Policy Guardrails Demo - Cleanup Script
# Removes all demo resources including Kyverno installation

set -e

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN}🧹 Policy Guardrails Demo - Cleanup${NC}"
echo -e "${CYAN}====================================${NC}"
echo "Removing all demo resources and Kyverno installation"
echo ""

echo -e "${CYAN}[1/4] Removing demo namespace${NC}"
kubectl delete namespace demo-star-lord --ignore-not-found
echo "✅ Demo namespace removed"

echo -e "${CYAN}[2/4] Removing Kyverno policies${NC}"
kubectl delete clusterpolicy require-nonroot-demo --ignore-not-found
echo "✅ Kyverno policies removed"

echo -e "${CYAN}[3/4] Uninstalling Kyverno${NC}"
if command -v helm &> /dev/null; then
    echo "Using Helm to uninstall Kyverno..."
    helm uninstall kyverno -n kyverno --ignore-not-found
else
    echo "Helm not found. Removing Kyverno manually..."
    kubectl delete namespace kyverno --ignore-not-found
fi

# Clean up any remaining Kyverno resources
echo "Cleaning up remaining Kyverno resources..."
kubectl get crd | grep kyverno | awk '{print $1}' | xargs -r kubectl delete crd --ignore-not-found
kubectl get crd | grep wgpolicyk8s | awk '{print $1}' | xargs -r kubectl delete crd --ignore-not-found
kubectl get clusterrole | grep kyverno | awk '{print $1}' | xargs -r kubectl delete clusterrole --ignore-not-found
kubectl get clusterrolebinding | grep kyverno | awk '{print $1}' | xargs -r kubectl delete clusterrolebinding --ignore-not-found

echo "✅ Kyverno completely removed"

echo -e "${CYAN}[4/4] Cleaning up temporary files${NC}"
rm -f /tmp/unsigned-result.txt /tmp/root-result.txt /tmp/test-root-pod.yaml
rm -f unsigned-result.txt root-result.txt
echo "✅ Temporary files cleaned"

echo ""
echo -e "${GREEN}✅ Cleanup completed successfully!${NC}"
echo ""
echo "Removed resources:"
echo "• demo-star-lord namespace"
echo "• require-nonroot-demo ClusterPolicy"
echo "• Kyverno admission controller"
echo "• All Kyverno CRDs and RBAC resources"
echo "• Temporary files"
echo ""
echo -e "${YELLOW}Note:${NC} Docker images (guardian-demo:secure, guardian-demo:insecure) are preserved for reuse"