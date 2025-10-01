#!/bin/bash
# Zero Trust Networking Demo - Cleanup Script
# Removes demo namespace and network policies

set -e

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${CYAN}🧹 Zero Trust Networking Demo - Cleanup${NC}"
echo -e "${CYAN}========================================${NC}"
echo "Removing demo namespace and network policies"
echo ""

echo -e "${CYAN}[1/1] Removing demo namespace${NC}"
kubectl delete namespace demo-groot --ignore-not-found
echo "✅ Demo namespace removed (includes all pods, services, and network policies)"

echo ""
echo -e "${GREEN}✅ Cleanup completed successfully!${NC}"
echo ""
echo "Removed resources:"
echo "• demo-groot namespace"
echo "• frontend, api, and db deployments"
echo "• tester pod"
echo "• All NetworkPolicies (default-deny and allow policies)"