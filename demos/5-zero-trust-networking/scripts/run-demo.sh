#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(dirname "$SCRIPT_DIR")"
MANIFESTS_DIR="$DEMO_DIR/manifests"

# Interactive pause function
pause() {
    echo ""
    if [[ "${DEMO_AUTOMATED:-false}" == "true" || ! -t 0 ]]; then
        echo -e "\033[33m[automated mode] continuing...\033[0m"
        return
    fi
    echo -e "\033[33mPress Enter to continue...\033[0m"
    read -r
}

echo -e "\033[36m╔════════════════════════════════════════════╗\033[0m"
echo -e "\033[36m║  Zero Trust Networking Demo              ║\033[0m"
echo -e "\033[36m╚════════════════════════════════════════════╝\033[0m"
echo ""
echo "This demo demonstrates Kubernetes Network Policies for Zero Trust:"
echo "  1. Deploy a 3-tier application (frontend, api, db)"
echo "  2. Apply default-deny policies (block all traffic)"
echo "  3. Selectively allow only required communication"
echo "  4. Verify traffic is blocked/allowed as expected"
echo ""
echo -e "\033[33m⚠️  IMPORTANT: Network Policies require a CNI plugin\033[0m"
echo ""

# Check if network policies are supported. Capture output first so `grep -q`
# does not close the pipe early and trip `set -o pipefail` on kubectl SIGPIPE.
CNI_PODS="$(kubectl get pods -n kube-system 2>/dev/null || true)"
if ! grep -qE "calico|cilium|weave" <<< "$CNI_PODS"; then
    echo -e "\033[31m❌ No network policy controller detected!\033[0m"
    echo ""
    echo "Docker Desktop Kubernetes doesn't support network policies."
    echo ""
    echo -e "\033[36mTo run this demo with enforcement:\033[0m"
    echo "  1. Run: ../../scripts/setup-kind-cluster.sh"
    echo "  2. Switch context: kubectl config use-context kind-container-security"
    echo "  3. Run this demo again"
    echo ""
    echo -e "\033[33mContinuing in simulation mode...\033[0m"
    echo "Network policies will be created but NOT enforced."
    echo ""
fi

pause

echo -e "\033[36m[1/8] Creating namespace\033[0m"
kubectl create namespace demo-groot --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace created"

pause

echo -e "\033[36m[2/8] Deploying services\033[0m"
echo "Deploying 3-tier application:"
echo "  - Frontend (web UI)"
echo "  - API (backend service)"
echo "  - Database (data layer)"
echo ""
kubectl apply -f "$MANIFESTS_DIR/base-services.yaml"
kubectl rollout status deployment/frontend -n demo-groot
kubectl rollout status deployment/api -n demo-groot
kubectl rollout status deployment/db -n demo-groot
echo ""
echo "✅ All services deployed and ready"
echo ""
echo -e "\033[36m🌐 Access the frontend:\033[0m"
echo "   In a new terminal, run:"
echo "   kubectl port-forward -n demo-groot svc/frontend 8080:80"
echo "   Then open: http://localhost:8080"
echo ""
echo -e "\033[33m📊 Current state: All pods can communicate freely (no network policies)\033[0m"

pause

echo -e "\033[36m[3/8] Applying default deny policies\033[0m"
echo "Applying Zero Trust network policies that deny all ingress and egress..."
kubectl apply -f "$MANIFESTS_DIR/default-deny.yaml"
echo ""
echo "✅ Default deny policies applied"
echo ""
echo -e "\033[33m📊 Current state: All traffic blocked! Services cannot communicate.\033[0m"

pause

echo -e "\033[36m[4/8] Applying allow policies\033[0m"
echo "Now adding specific allow rules:"
echo "  - Frontend → API (port 8080)"
echo "  - API → Database (port 5432)"
echo "  - DNS for all pods"
echo ""
kubectl apply -f "$MANIFESTS_DIR/allow-policies.yaml"
echo ""
echo "✅ Allow policies applied"
echo ""
echo -e "\033[33m📊 Current state: Only approved paths work. Everything else blocked.\033[0m"

pause

echo -e "\033[36m[5/8] Launching tester pod\033[0m"
echo "Deploying a test pod that is NOT in the allow policies..."
kubectl apply -f "$MANIFESTS_DIR/tester-pod.yaml"
kubectl wait --for=condition=Ready pod/tester -n demo-groot --timeout=60s
echo "✅ Tester pod ready"

pause

echo -e "\033[36m[6/8] Testing blocked traffic\033[0m"
echo "Testing that the tester pod CANNOT reach api or db (should fail)..."
echo ""

echo -e "\033[36mTest 1: tester → api\033[0m"
set +e  # Temporarily disable exit on error
TEST1_OUTPUT=$(kubectl exec -n demo-groot tester -- curl -sS --connect-timeout 3 api:8080/get 2>&1)
TEST1_EXIT=$?
set -e  # Re-enable exit on error
if [[ $TEST1_EXIT -eq 0 ]]; then
    echo -e "\033[31m❌ Connection succeeded (should be blocked by network policy)\033[0m"
    echo -e "\033[33m   Note: Network policies may not be enforced on this cluster\033[0m"
else
    echo -e "\033[32m✅ Connection blocked by network policy\033[0m"
fi

echo ""
echo -e "\033[36mTest 2: tester → db\033[0m"
set +e  # Temporarily disable exit on error
kubectl exec -n demo-groot tester -- curl -sS --connect-timeout 3 db:5432 2>/dev/null
TEST2_EXIT=$?
set -e  # Re-enable exit on error
if [[ $TEST2_EXIT -eq 0 ]]; then
    echo -e "\033[31m❌ Connection succeeded (should be blocked by network policy)\033[0m"
    echo -e "\033[33m   Note: Network policies may not be enforced on this cluster\033[0m"
else
    echo -e "\033[32m✅ Connection blocked by network policy\033[0m"
fi

echo ""
echo -e "\033[36mTest 3: frontend → api (should work)\033[0m"
# The frontend image (nginxdemos/hello) ships no curl/wget, so we probe from a
# short-lived curl pod labeled app=frontend. The allow-frontend-* policies key
# on that label, so this traffic takes the genuine allowed path to the API.
echo "Probing from an ephemeral curl pod labeled app=frontend (allowed by policy)..."
set +e  # Temporarily disable exit on error
TEST3_OUTPUT=$(kubectl run frontend-probe -n demo-groot --rm -i --restart=Never \
    --labels=app=frontend --image=curlimages/curl:8.8.0 --command -- \
    curl -sS --connect-timeout 3 api:8080/get 2>&1)
set -e  # Re-enable exit on error
if echo "$TEST3_OUTPUT" | grep -q '"url"'; then
    echo -e "\033[32m✅ Frontend can reach API (allowed by policy)\033[0m"
else
    echo -e "\033[31m❌ Frontend blocked (unexpected)\033[0m"
    echo -e "\033[33m   Output: ${TEST3_OUTPUT}\033[0m"
fi

pause

echo -e "\033[36m[7/8] Temporarily allowing tester to api\033[0m"
echo "Adding a new policy to allow tester → api..."
kubectl apply -f "$MANIFESTS_DIR/allow-tester-api.yaml"
echo "Waiting for policy to take effect..."
sleep 3
echo ""
echo -e "\033[36mTest: tester → api (should now work)\033[0m"
set +e  # Temporarily disable exit on error
kubectl exec -n demo-groot tester -- curl -sS --connect-timeout 3 api:8080/get 2>/dev/null
TEST4_EXIT=$?
set -e  # Re-enable exit on error
if [[ $TEST4_EXIT -eq 0 ]]; then
    echo -e "\033[32m✅ Success: Tester can now reach API (allowed by new policy)\033[0m"
else
    echo -e "\033[31m❌ Failed: Connection still blocked\033[0m"
fi

pause

echo -e "\033[36m[8/8] Cleanup\033[0m"
echo "Removing temporary allow policy and cleaning up namespace..."
kubectl delete -f "$MANIFESTS_DIR/allow-tester-api.yaml" --ignore-not-found
kubectl delete namespace demo-groot --ignore-not-found

echo ""
echo -e "\033[32m✅ Demo complete!\033[0m"
echo ""
echo -e "\033[36mKey Takeaways:\033[0m"
echo "  • Zero Trust: Default deny, explicit allow"
echo "  • Network policies provide microsegmentation"
echo "  • Policies are enforced at the pod level"
echo "  • Changes take effect in seconds"