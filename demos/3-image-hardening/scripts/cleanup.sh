#!/bin/bash
# Image Hardening Demo - Cleanup Script
# Removes demo images and reports

set -e

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN}🧹 Image Hardening Demo - Cleanup${NC}"
echo -e "${CYAN}==================================${NC}"
echo "Removing demo images and reports"
echo ""

echo -e "${CYAN}[1/2] Removing demo images${NC}"
docker rmi guardian-demo:before 2>/dev/null || true
docker rmi guardian-demo:after 2>/dev/null || true
echo "✅ Demo images removed"

echo -e "${CYAN}[2/2] Removing vulnerability reports${NC}"
rm -rf ../reports/*.txt 2>/dev/null || true
echo "✅ Reports cleaned"

echo ""
echo -e "${GREEN}✅ Cleanup completed successfully!${NC}"
echo ""
echo "Removed resources:"
echo "• guardian-demo:before image"
echo "• guardian-demo:after image"
echo "• Vulnerability scan reports"