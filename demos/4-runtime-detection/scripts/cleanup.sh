#!/bin/bash
# Runtime Detection Demo - Cleanup Script
# Removes Falco and demo resources

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(dirname "$SCRIPT_DIR")"
MANIFESTS_DIR="$DEMO_DIR/manifests"

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN}🧹 Runtime Detection Demo - Cleanup${NC}"
echo -e "${CYAN}====================================${NC}"
echo "Removing Falco and demo resources"
echo ""

echo -e "${CYAN}[1/4] Removing demo namespace${NC}"
kubectl delete namespace demo-drax --ignore-not-found
echo "✅ Demo namespace removed"

echo -e "${CYAN}[2/4] Removing trigger pod${NC}"
kubectl delete -f "$MANIFESTS_DIR/trigger-pod.yaml" --ignore-not-found 2>/dev/null || true
echo "✅ Trigger pod removed"

echo -e "${CYAN}[3/4] Custom rules${NC}"
echo "✅ Custom rule is delivered via Helm customRules; removed with the Falco release below"

echo -e "${CYAN}[4/4] Uninstalling Falco${NC}"
if command -v helm &> /dev/null; then
    echo "Using Helm to uninstall Falco..."
    if helm list -n falco | grep -q falco; then
        helm uninstall falco -n falco
        echo "✅ Falco Helm release uninstalled"
    else
        echo "No Falco Helm release found"
    fi
else
    echo "Helm not found. Removing Falco manually..."
fi

echo -e "${CYAN}Removing Falco namespace${NC}"
kubectl delete namespace falco --ignore-not-found 2>/dev/null || true
echo "✅ Falco namespace removed"

echo ""
echo -e "${GREEN}✅ Cleanup completed successfully!${NC}"
echo ""
echo "Removed resources:"
echo "• demo-drax namespace"
echo "• Trigger pod"
echo "• Custom Falco rules"
echo "• Falco installation"
echo "• Falco namespace"
echo ""
echo -e "${YELLOW}Note:${NC} To keep Falco for exploration, comment out the uninstall step in the script"