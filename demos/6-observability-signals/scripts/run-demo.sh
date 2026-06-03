#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$DEMO_DIR/app"
COLLECTOR_DIR="$DEMO_DIR/collector"
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

NAMESPACE="${1:-demo-mantis}"
IMAGE="guardian-telemetry:local"

echo -e "\033[36m╔════════════════════════════════════════════╗\033[0m"
echo -e "\033[36m║  Observability Signals Demo               ║\033[0m"
echo -e "\033[36m╚════════════════════════════════════════════╝\033[0m"
echo ""
echo "This demo shows how to collect and correlate:"
echo "  • OpenTelemetry traces, metrics, and logs"
echo "  • Falco security events"
echo "  • Unified observability for security & performance"
echo ""

pause

echo -e "\033[36m[1/9] Building telemetry image locally\033[0m"
echo "Building instrumented Python app..."
pushd "$APP_DIR" > /dev/null
docker build -t "$IMAGE" .
popd > /dev/null
echo "✅ Image built"

# Check if running on kind cluster and load image
CURRENT_CONTEXT=$(kubectl config current-context)
if [[ "$CURRENT_CONTEXT" == kind-* ]]; then
    CLUSTER_NAME="${CURRENT_CONTEXT#kind-}"
    echo ""
    echo "Detected kind cluster: $CLUSTER_NAME"
    echo "Loading image into kind cluster..."
    if command -v kind &> /dev/null; then
        kind load docker-image "$IMAGE" --name "$CLUSTER_NAME"
        echo "✅ Image loaded into kind"
    else
        echo "⚠️  kind command not found. You may need to manually load the image:"
        echo "   kind load docker-image $IMAGE --name $CLUSTER_NAME"
    fi
fi

pause

echo -e "\033[36m[2/9] Creating namespace\033[0m"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
# Clean up any existing deployment to ensure fresh start
kubectl delete deployment guardian-telemetry -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
echo "✅ Namespace ready"

pause

echo -e "\033[36m[3/9] Deploying OpenTelemetry collector\033[0m"
kubectl apply -f "$COLLECTOR_DIR/otel-collector.yaml" --namespace "$NAMESPACE"
kubectl rollout status deployment/otel-collector -n "$NAMESPACE"
echo "✅ OTEL collector running"

pause

echo -e "\033[36m[4/9] Installing Falcosidekick\033[0m"
echo "Connecting Falco to OpenTelemetry..."
echo "Deploying Falco→OTLP adapter (translates Falco webhooks into OTLP logs)..."
kubectl apply -f "$MANIFESTS_DIR/falco-otlp-adapter.yaml" -n "$NAMESPACE"
kubectl rollout status deployment/falco-otlp-adapter -n "$NAMESPACE"
helm repo add falcosecurity https://falcosecurity.github.io/charts > /dev/null 2>&1 || true
helm repo update > /dev/null
helm upgrade --install falcosidekick falcosecurity/falcosidekick \
  --namespace falco \
  --create-namespace \
  -f "$MANIFESTS_DIR/falcosidekick-config.yaml" \
  --wait
if helm status falco -n falco >/dev/null 2>&1; then
  echo "Configuring Falco HTTP output to send alerts to Falcosidekick..."
  helm upgrade falco falcosecurity/falco \
    --namespace falco \
    --reuse-values \
    --set falco.json_output=true \
    --set falco.http_output.enabled=true \
    --set falco.http_output.url=http://falcosidekick.falco.svc.cluster.local:2801/ \
    --wait
else
  echo "⚠️  Falco release not found. Run demo 4 first to generate security alerts."
fi
echo "✅ Falcosidekick configured"

pause

echo -e "\033[36m[5/9] Deploying instrumented API\033[0m"
echo "Starting Python app with OpenTelemetry..."
# Ensure namespace exists
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null
kubectl apply -f "$MANIFESTS_DIR/instrumented-api.yaml" -n "$NAMESPACE"
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/guardian-telemetry -n "$NAMESPACE" || {
    echo "Deployment failed. Checking status..."
    kubectl get pods -n "$NAMESPACE"
    kubectl describe pod -n "$NAMESPACE" -l app=guardian-telemetry | tail -20
    exit 1
}
echo "✅ API running"

pause

echo -e "\033[36m[6/9] Generating test traffic\033[0m"
echo "Creating traces and metrics..."
kubectl apply -f "$MANIFESTS_DIR/load-generator.yaml" -n "$NAMESPACE"
kubectl wait --for=condition=complete job/telemetry-load -n "$NAMESPACE" --timeout=120s
echo "✅ Traffic generated"
echo ""
echo "Waiting 5 seconds for traces to be processed..."
sleep 5

pause

echo -e "\033[36m[7/9] Viewing telemetry data\033[0m"
echo "Checking application logs for sent traces..."
echo ""
kubectl logs deployment/guardian-telemetry -n "$NAMESPACE" --tail=20 | grep -i "handled\|hello\|anomaly" || echo "No app logs found"
echo ""
echo "Checking OTEL collector for received traces..."
echo ""
# Look for trace data in collector logs
kubectl logs deployment/otel-collector -n "$NAMESPACE" --tail=100 | grep -E "ResourceSpans|Span #|guardian-telemetry|ScopeSpans" || {
    echo "No trace structures found. Showing recent collector activity:"
    kubectl logs deployment/otel-collector -n "$NAMESPACE" --tail=20
}

pause

echo -e "\033[36m[8/9] Next steps\033[0m"
echo ""
echo "📊 View Prometheus metrics:"
echo "   kubectl port-forward svc/otel-collector -n $NAMESPACE 9464:9464"
echo "   Open: http://localhost:9464/metrics"
echo ""
echo "🔍 View live collector logs:"
echo "   kubectl logs -f deployment/otel-collector -n $NAMESPACE"
echo ""
echo "🚨 Trigger Falco alerts (requires demo 4):"
echo "   cd ../../4-runtime-detection/scripts && ./run-demo.sh"

pause

echo -e "\033[36m[9/9] Cleanup\033[0m"
echo "To remove all resources, run:"
echo "   ./cleanup.sh"
echo ""
echo -e "\033[32m✅ Demo complete!\033[0m"