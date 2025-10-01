#!/bin/bash
# Supply Chain Trust Demo - Cleanup Script
# Removes local registry and generated artifacts

set -e

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN}🧹 Supply Chain Trust Demo - Cleanup${NC}"
echo -e "${CYAN}======================================${NC}"
echo "Removing local registry and artifacts"
echo ""

echo -e "${CYAN}[1/3] Stopping and removing local registry${NC}"
docker stop registry 2>/dev/null || true
docker rm registry 2>/dev/null || true
echo "✅ Local registry removed"

echo -e "${CYAN}[2/3] Removing generated artifacts${NC}"
rm -rf ../artifacts/*.json ../artifacts/*.txt ../artifacts/*.spdx 2>/dev/null || true
echo "✅ Artifacts cleaned"

echo -e "${CYAN}[3/3] Removing demo images${NC}"
docker rmi localhost:5000/guardian-demo-app:v0.1.0-secure 2>/dev/null || true
docker rmi guardian-demo-app:v0.1.0-secure 2>/dev/null || true
echo "✅ Demo images removed"

echo ""
echo -e "${GREEN}✅ Cleanup completed successfully!${NC}"
echo ""
echo "Removed resources:"
echo "• Local Docker registry container"
echo "• Generated SBOMs and scan reports"
echo "• Demo container images"
echo ""
echo -e "${YELLOW}Note:${NC} Cosign keys in ../keys/ are preserved for reuse"