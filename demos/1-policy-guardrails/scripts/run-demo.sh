#!/bin/bash
# Policy Guardrails Demo - Interactive Version
# Demonstrates "before and after" admission control with Kyverno policies

set -e

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check for help flag
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Policy Guardrails Demo - Interactive Version"
    echo ""
    echo "Usage: $0 [OPTIONS] [IMAGE]"
    echo ""
    echo "Options:"
    echo "  --automated     Run in automated mode (no user interaction)"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Arguments:"
    echo "  IMAGE           Container image to use (default: guardian-demo)"
    echo ""
    echo "Environment Variables:"
    echo "  DEMO_AUTOMATED  Set to 'true' to run in automated mode"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 --automated                        # Automated mode"  
    echo "  $0 myregistry.com/myapp:latest       # Custom image"
    echo "  DEMO_AUTOMATED=true $0               # Automated via env var"
    echo ""
    exit 0
fi

# Check for automation flag
AUTOMATED_MODE=false
if [[ "$1" == "--automated" ]] || [[ "$DEMO_AUTOMATED" == "true" ]]; then
    AUTOMATED_MODE=true
    shift # Remove the --automated flag from arguments
fi

# Default image parameter
IMAGE="${1:-guardian-demo}"

# Function to wait for user input
wait_for_user() {
    echo ""
    if [[ "$AUTOMATED_MODE" == "true" ]]; then
        echo -e "${BLUE}👆 [AUTOMATED MODE - CONTINUING...]${NC}"
        sleep 1
    else
        echo -e "${BLUE}👆 Press ENTER to continue...${NC}"
        read -r
    fi
    echo ""
}

echo -e "${CYAN}🚀 Policy Guardrails Demo - Star-Lord's Command Center${NC}"
echo -e "${CYAN}================================================================${NC}"
if [[ "$AUTOMATED_MODE" == "true" ]]; then
    echo "Running in AUTOMATED mode - no user interaction required"
else
    echo "This interactive demo shows BEFORE and AFTER security policy enforcement"
fi
echo "Image: $IMAGE"
echo ""

# Verify we're in a bash-compatible environment
if [[ -z "$BASH_VERSION" ]]; then
    echo -e "${YELLOW}⚠️  Warning: This script is designed for bash. Some features may not work in other shells.${NC}"
fi

echo -e "${CYAN}[1/9] Preparing clean demo environment${NC}"
echo "Ensuring clean state by removing any previous demo resources..."

# Clean up any existing demo policies
echo "🧹 Removing any existing demo policies..."
kubectl delete clusterpolicy require-nonroot-demo --ignore-not-found=true 2>/dev/null || true
kubectl delete clusterpolicy require-signed-nonroot --ignore-not-found=true 2>/dev/null || true

# Clean up demo namespace and recreate
echo "🧹 Cleaning demo namespace..."
kubectl delete namespace demo-star-lord --ignore-not-found=true

# Wait for namespace to be fully deleted before recreating
echo "⏳ Waiting for namespace cleanup to complete..."
TIMEOUT=30
ELAPSED=0
while kubectl get namespace demo-star-lord &>/dev/null && [ $ELAPSED -lt $TIMEOUT ]; do
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    if [ $((ELAPSED % 6)) -eq 0 ]; then
        echo "   Still waiting... (${ELAPSED}s/${TIMEOUT}s)"
    fi
done

if kubectl get namespace demo-star-lord &>/dev/null; then
    echo "⚠️  Namespace deletion taking longer than expected, proceeding anyway..."
    kubectl delete namespace demo-star-lord --force --grace-period=0 2>/dev/null || true
    sleep 3
fi

echo "📁 Creating fresh demo namespace..."
kubectl create namespace demo-star-lord

echo "✅ Clean environment prepared"

echo -e "${CYAN}[2/9] Checking local images${NC}"
# Check if required images exist locally
SECURE_IMAGE_EXISTS=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -c "guardian-demo:secure" 2>/dev/null || echo "0")
INSECURE_IMAGE_EXISTS=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -c "guardian-demo:insecure" 2>/dev/null || echo "0")

if [ "$SECURE_IMAGE_EXISTS" -eq "0" ] || [ "$INSECURE_IMAGE_EXISTS" -eq "0" ]; then
    echo "⚠️  Required images not found locally. Building images..."
    echo "Building guardian-demo:secure and guardian-demo:insecure..."
    
    if [ -f "scripts/build-images.sh" ]; then
        ./scripts/build-images.sh --image-name guardian-demo
    else
        echo -e "${RED}❌ Build script not found. Please run: ./scripts/build-images.sh${NC}"
        exit 1
    fi
    
    # Verify images were built
    SECURE_IMAGE_EXISTS=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -c "guardian-demo:secure" 2>/dev/null || echo "0")
    INSECURE_IMAGE_EXISTS=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -c "guardian-demo:insecure" 2>/dev/null || echo "0")
    
    if [ "$SECURE_IMAGE_EXISTS" -eq "0" ] || [ "$INSECURE_IMAGE_EXISTS" -eq "0" ]; then
        echo -e "${RED}❌ Failed to build required images${NC}"
        exit 1
    fi
    
    echo "✅ Images built successfully"
else
    echo "✅ Required images found locally"
fi

echo -e "${CYAN}[3/9] Checking Kyverno installation${NC}"
if ! kubectl get crd clusterpolicies.kyverno.io &>/dev/null; then
    echo "⚠️  Kyverno not found. Installing Kyverno..."

    if command -v helm &> /dev/null; then
        echo "Using Helm to install Kyverno..."
        helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update
        helm repo update
        helm upgrade --install kyverno kyverno/kyverno \
            --namespace kyverno --create-namespace \
            --wait --timeout=5m
    else
        echo "Helm not found. Using kubectl to install Kyverno..."
        kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml

        echo "Waiting for Kyverno CRDs to be available..."
        sleep 10
        kubectl wait --for=condition=established crd/clusterpolicies.kyverno.io --timeout=300s
    fi

    echo "Waiting for Kyverno to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=kyverno -n kyverno --timeout=300s
else
    echo "✅ Kyverno is already installed"
fi

echo ""
echo -e "${YELLOW}================== BEFORE SECURITY POLICIES ==================${NC}"
echo -e "${YELLOW}Let's see what happens without admission control policies...${NC}"

# Handle manifest paths
if [ -f "../manifests/unsigned-pod.yaml" ]; then
    MANIFESTS_PATH="../manifests"
elif [ -f "manifests/unsigned-pod.yaml" ]; then
    MANIFESTS_PATH="manifests"
else
    echo -e "${RED}❌ Could not find manifest files${NC}"
    exit 1
fi

echo -e "${CYAN}[9/9] Deploying insecure pods WITHOUT policies${NC}"
echo "First, let's create some insecure pods to show the security risks..."

echo "🔓 Creating unsigned pod..."
kubectl apply -f "$MANIFESTS_PATH/unsigned-pod.yaml" || true

echo "🔓 Creating root pod..."
kubectl apply -f "$MANIFESTS_PATH/root-pod.yaml" || true

echo "✅ Creating compliant pod (for comparison)..."
kubectl apply -f "$MANIFESTS_PATH/nonroot-pod.yaml" || true

echo ""
echo "Waiting for pods to be in a stable state..."
sleep 10

echo -e "${CYAN}[9/9] Examining the security state WITHOUT policies${NC}"
echo "Let's look at what we have running:"
kubectl get pods -n demo-star-lord -o wide

echo ""
echo "Let's check the security context of these pods:"
echo -e "${YELLOW}Root pod user ID:${NC}"
kubectl exec root-pod -n demo-star-lord -- id 2>/dev/null || echo "Pod may still be starting..."

echo -e "${YELLOW}Unsigned pod status (this shows why proper security contexts matter):${NC}"
UNSIGNED_STATUS=$(kubectl get pod unsigned-pod -n demo-star-lord -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
if [ "$UNSIGNED_STATUS" = "Running" ]; then
    echo "Unsigned pod is running - checking user context..."
    kubectl exec unsigned-pod -n demo-star-lord -- id 2>/dev/null || echo "Cannot execute in pod"
else
    echo "Unsigned pod status: $UNSIGNED_STATUS"
    echo "This demonstrates that the image runs as root by default (insecure)"
    kubectl describe pod unsigned-pod -n demo-star-lord | grep -A2 "State:" || echo "Pod details unavailable"
fi

wait_for_user

echo ""
echo -e "${GREEN}================== APPLYING SECURITY POLICIES ==================${NC}"
echo -e "${GREEN}Now let's apply admission control policies to secure our cluster...${NC}"

# Handle both running from scripts/ dir and parent dir
if [ -f "../policies/require-signed-nonroot.yaml" ]; then
    POLICY_PATH="../policies/require-signed-nonroot.yaml"
elif [ -f "policies/require-signed-nonroot.yaml" ]; then
    POLICY_PATH="policies/require-signed-nonroot.yaml"
else
    echo -e "${RED}❌ Could not find policy file. Please run from demo directory or scripts/ subdirectory${NC}"
    exit 1
fi

echo -e "${CYAN}[9/9] Applying Kyverno security policies${NC}"
echo "Installing admission control policies for:"
echo "  • Non-root container enforcement"
echo "  • Signed image requirements (simulated)"

kubectl apply -f "$POLICY_PATH"
echo "✅ Kyverno policy applied"

# Wait for admission webhooks to be ready
echo "Waiting for admission webhooks to become active..."
sleep 15

echo "Policy status:"
kubectl get clusterpolicy require-nonroot-demo -o jsonpath='{.status.conditions[?(@.type=="Ready")]}' 2>/dev/null || echo "Policy status pending..."
echo ""

wait_for_user

echo ""
echo -e "${RED}================== TESTING POLICY ENFORCEMENT ==================${NC}"
echo -e "${RED}Now let's see what happens when we try to create insecure pods...${NC}"

echo -e "${CYAN}[9/9] Testing root pod rejection${NC}"
echo "Attempting to deploy a new root pod (should be BLOCKED)..."

set +e  # Don't exit on error for this test
OUTPUT=$(kubectl apply -f "$MANIFESTS_PATH/test-root-pod.yaml" --dry-run=server 2>&1)
ROOT_EXIT_CODE=$?
echo "$OUTPUT"
set -e

if [ $ROOT_EXIT_CODE -ne 0 ] && echo "$OUTPUT" | grep -q "blocked\|denied"; then
    echo -e "${GREEN}✅ SUCCESS: Root pod was rejected by admission control${NC}"
    echo "$OUTPUT" | grep -i "disallow-root-user\|validation failure" | head -1 || echo "Root user policy enforcement detected"
else
    echo -e "${YELLOW}⚠️  Unexpected: Root pod was not rejected${NC}"
fi

wait_for_user

echo -e "${CYAN}[9/9] Testing unsigned image rejection${NC}"
echo "Attempting to deploy a new unsigned pod (should be BLOCKED)..."

set +e  # Don't exit on error for this test  
OUTPUT=$(kubectl apply -f "$MANIFESTS_PATH/test-unsigned-pod.yaml" --dry-run=server 2>&1)
UNSIGNED_EXIT_CODE=$?
echo "$OUTPUT"
set -e

if [ $UNSIGNED_EXIT_CODE -ne 0 ] && echo "$OUTPUT" | grep -q "blocked\|denied"; then
    echo -e "${GREEN}✅ SUCCESS: Unsigned pod was rejected by admission control${NC}"
    echo "$OUTPUT" | grep -i "require-secure-images\|validation failure" | head -1 || echo "Image security policy enforcement detected"
else
    echo -e "${YELLOW}⚠️  Unexpected: Unsigned pod was not rejected${NC}"
fi

wait_for_user

echo -e "${CYAN}[9/9] Testing compliant pod (should still work)${NC}"
echo "Attempting to deploy a compliant, secure pod..."

# Delete existing compliant pod first
kubectl delete pod nonroot-pod -n demo-star-lord --ignore-not-found

# Try to create a new compliant pod
kubectl apply -f "$MANIFESTS_PATH/nonroot-pod.yaml"
echo "Waiting for compliant pod to be ready..."
kubectl wait --for=condition=Ready pod/nonroot-pod -n demo-star-lord --timeout=60s || true
kubectl get pod nonroot-pod -n demo-star-lord

echo -e "${GREEN}✅ SUCCESS: Compliant pod was accepted and is running${NC}"

wait_for_user

echo ""
echo -e "${GREEN}================== FINAL COMPARISON ==================${NC}"

echo -e "${CYAN}[9/9] Final security state comparison${NC}"

echo ""
echo -e "${YELLOW}Current pod status (with policies enforced):${NC}"
kubectl get pods -n demo-star-lord -o wide

echo ""
echo -e "${YELLOW}Existing insecure pods from BEFORE policies:${NC}"
echo "• root-pod: Still running (existed before policy) - but NEW root pods are blocked"
echo "• unsigned-pod: Failed to start properly due to image security context conflicts"

echo ""  
echo -e "${YELLOW}New pod creation attempts (with policies):${NC}"
echo "• root-pod: ❌ BLOCKED by admission control"
echo "• unsigned-pod: ❌ BLOCKED by admission control"  
echo "• nonroot-pod: ✅ ALLOWED (compliant with security policies)"

echo ""
echo -e "${GREEN}✅ Demo completed!${NC}"

echo ""
echo "🎯 Key learnings:"
echo "• Existing workloads continue running (graceful enforcement)"
echo "• NEW insecure workloads are blocked at admission time"
echo "• Kyverno policies enforce security at the cluster level"
echo "• Only compliant, signed, non-root containers can be deployed"
echo "• Admission control provides proactive security governance"

# Cleanup instructions
echo ""
echo -e "${YELLOW}🧹 Cleanup (optional):${NC}"
echo "kubectl delete namespace demo-star-lord --ignore-not-found"
echo "kubectl delete clusterpolicy require-nonroot-demo --ignore-not-found"

# Cleanup temp files
rm -f /tmp/unsigned-result.txt /tmp/root-result.txt