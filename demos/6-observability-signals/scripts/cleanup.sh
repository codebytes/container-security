#!/bin/bash
# Observability Signals Demo - Cleanup Script
# Removes demo namespace and Falcosidekick

set -e

NAMESPACE="${1:-demo-mantis}"

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN}🧹 Observability Signals Demo - Cleanup${NC}"
echo -e "${CYAN}========================================${NC}"
echo "Removing demo namespace and Falcosidekick"
echo ""

echo -e "${CYAN}[1/3] Removing demo namespace${NC}"
kubectl delete namespace "$NAMESPACE" --ignore-not-found
echo "✅ Demo namespace removed (includes OTEL collector and instrumented API)"

echo -e "${CYAN}[2/3] Uninstalling Falcosidekick${NC}"
if command -v helm &> /dev/null; then
    echo "Using Helm to uninstall Falcosidekick..."
    helm uninstall falcosidekick -n falco --ignore-not-found 2>/dev/null || true
else
    echo "Helm not found. Skipping Falcosidekick removal..."
fi
echo "✅ Falcosidekick removed"

echo -e "${CYAN}[3/3] Removing demo image (optional)${NC}"
docker rmi ghcr.io/codebytes/guardian-telemetry:0.1.0 2>/dev/null || echo "Image not found locally (skipping)"
echo "✅ Cleanup completed"

echo ""
echo -e "${GREEN}✅ Cleanup completed successfully!${NC}"
echo ""
echo "Removed resources:"
echo "• $NAMESPACE namespace"
echo "• OTEL collector deployment"
echo "• Instrumented API and load generator"
echo "• Falcosidekick installation"
echo ""
echo -e "${YELLOW}Note:${NC} Falco installation is preserved. To remove, run cleanup from demo 4"