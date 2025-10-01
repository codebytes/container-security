#!/bin/bash
# Push Individual Demo Images to Docker Hub
# Usage: ./push-demo.sh <demo_number> [tag]

set -e

DEMO_NUMBER="$1"
TAG="${2:-latest}"
REGISTRY="${DOCKER_REGISTRY:-codebytes}"

if [ -z "$DEMO_NUMBER" ]; then
    echo "Usage: $0 <demo_number> [tag]"
    echo ""
    echo "Available demos:"
    echo "  1 - Policy Guardrails"
    echo "  2 - Supply Chain Trust"
    echo "  3 - Image Hardening"
    echo "  6 - Observability Signals"
    echo "  src - Source images"
    echo "  all - Push all built images"
    exit 1
fi

echo "🚀 Pushing Demo $DEMO_NUMBER to Docker Hub"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo

# Check Docker login
if ! docker info | grep -q "Username"; then
    echo "❌ Not logged into Docker Hub. Please run: docker login"
    exit 1
fi

push_image() {
    local image="$1"
    echo "Pushing $image..."
    if docker push "$image"; then
        echo "✅ Pushed: $image"
        echo "   View at: https://hub.docker.com/r/$image"
    else
        echo "❌ Failed to push: $image"
        return 1
    fi
}

case "$DEMO_NUMBER" in
    "1")
        echo "📋 Pushing Demo 1: Policy Guardrails"
        push_image "$REGISTRY/guardian-demo-secure:$TAG"
        push_image "$REGISTRY/guardian-demo-insecure:$TAG"
        ;;
    "2")
        echo "🔒 Pushing Demo 2: Supply Chain Trust"
        push_image "$REGISTRY/guardian-demo-app:$TAG"
        ;;
    "3")
        echo "🛡️ Pushing Demo 3: Image Hardening"
        push_image "$REGISTRY/guardian-demo-vulnerable:$TAG"
        push_image "$REGISTRY/guardian-demo-hardened:$TAG"
        ;;
    "6")
        echo "📊 Pushing Demo 6: Observability Signals"
        push_image "$REGISTRY/guardian-telemetry:$TAG"
        ;;
    "src")
        echo "🏗️ Pushing Source Images"
        push_image "$REGISTRY/guardian-demo:$TAG"
        push_image "$REGISTRY/guardian-demo-base-insecure:$TAG"
        ;;
    "all")
        echo "🌟 Pushing All Available Images"

        # Check which images exist locally and push them
        for image in \
            "$REGISTRY/guardian-demo-secure:$TAG" \
            "$REGISTRY/guardian-demo-insecure:$TAG" \
            "$REGISTRY/guardian-demo-app:$TAG" \
            "$REGISTRY/guardian-demo-vulnerable:$TAG" \
            "$REGISTRY/guardian-demo-hardened:$TAG" \
            "$REGISTRY/guardian-telemetry:$TAG" \
            "$REGISTRY/guardian-demo:$TAG" \
            "$REGISTRY/guardian-demo-base-insecure:$TAG"; do

            if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "^$image$"; then
                push_image "$image"
            else
                echo "⚠️ Image not found locally: $image (skipping)"
            fi
        done
        ;;
    *)
        echo "❌ Unknown demo number: $DEMO_NUMBER"
        echo "Available: 1, 2, 3, 6, src, all"
        exit 1
        ;;
esac

echo
echo "🎉 Push complete! Visit your Docker Hub repository:"
echo "  https://hub.docker.com/u/$REGISTRY"