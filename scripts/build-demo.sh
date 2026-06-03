#!/bin/bash
# Individual Demo Builder for Docker Hub
# Usage: ./build-demo.sh <demo_number> [tag]

set -e

DEMO_NUMBER="$1"
TAG="${2:-latest}"
REGISTRY="${DOCKER_REGISTRY:-codebytes}"

if [ -z "$DEMO_NUMBER" ]; then
    echo "Usage: $0 <demo_number> [tag]"
    echo ""
    echo "Available demos:"
    echo "  1 - Policy Guardrails (builds secure and insecure images)"
    echo "  2 - Supply Chain Trust"
    echo "  3 - Image Hardening (builds vulnerable and hardened images)"
    echo "  6 - Observability Signals"
    echo "  src - Source images"
    echo ""
    echo "Examples:"
    echo "  $0 2                    # Build demo 2 with latest tag"
    echo "  $0 3 v1.0.0            # Build demo 3 with v1.0.0 tag"
    echo "  DOCKER_REGISTRY=myorg $0 2   # Use custom registry"
    exit 1
fi

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "🚀 Building Demo $DEMO_NUMBER for Docker Hub"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo

case "$DEMO_NUMBER" in
    "1")
        echo "📋 Building Demo 1: Policy Guardrails"
        docker build -f demos/1-policy-guardrails/images/Dockerfile.secure \
            -t "$REGISTRY/guardian-demo-secure:$TAG" \
            demos/1-policy-guardrails
        docker build -f demos/1-policy-guardrails/images/Dockerfile.insecure \
            -t "$REGISTRY/guardian-demo-insecure:$TAG" \
            demos/1-policy-guardrails
        echo "✅ Built: guardian-demo-secure:$TAG and guardian-demo-insecure:$TAG"
        ;;
    "2")
        echo "🔒 Building Demo 2: Supply Chain Trust"
        docker build -f demos/2-supply-chain-trust/pipeline/Dockerfile \
            -t "$REGISTRY/guardian-demo-app:$TAG" \
            demos/2-supply-chain-trust
        echo "✅ Built: guardian-demo-app:$TAG"
        ;;
    "3")
        echo "🛡️ Building Demo 3: Image Hardening"
        docker build -f demos/3-image-hardening/dockerfiles/Dockerfile.before \
            -t "$REGISTRY/guardian-demo-vulnerable:$TAG" \
            demos/3-image-hardening
        docker build -f demos/3-image-hardening/dockerfiles/Dockerfile.after \
            -t "$REGISTRY/guardian-demo-hardened:$TAG" \
            demos/3-image-hardening
        echo "✅ Built: guardian-demo-vulnerable:$TAG and guardian-demo-hardened:$TAG"
        ;;
    "6")
        echo "📊 Building Demo 6: Observability Signals"
        docker build -f demos/6-observability-signals/app/Dockerfile \
            -t "$REGISTRY/guardian-telemetry:$TAG" \
            demos/6-observability-signals/app
        echo "✅ Built: guardian-telemetry:$TAG"
        ;;
    "src")
        echo "🏗️ Building Source Images"
        docker build -f src/Dockerfile \
            -t "$REGISTRY/guardian-demo:$TAG" \
            src
        docker build -f src/Dockerfile.insecure \
            -t "$REGISTRY/guardian-demo-base-insecure:$TAG" \
            src
        echo "✅ Built: guardian-demo:$TAG and guardian-demo-base-insecure:$TAG"
        ;;
    *)
        echo "❌ Unknown demo number: $DEMO_NUMBER"
        echo "Available: 1, 2, 3, 6, src"
        exit 1
        ;;
esac

echo
echo "🎉 Build complete! To push to Docker Hub:"
echo "  docker push $REGISTRY/[image-name]:$TAG"
echo
echo "Or use the push script:"
echo "  ./scripts/push-demo.sh $DEMO_NUMBER $TAG"