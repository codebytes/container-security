#!/bin/bash
# Build demo images for Policy Guardrails Demo

set -e

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="${REGISTRY:-}"
IMAGE_NAME="${IMAGE_NAME:-guardian-demo}"
PUSH_TO_REGISTRY="${PUSH_TO_REGISTRY:-false}"
BUILD_PLATFORM="${BUILD_PLATFORM:-linux/amd64,linux/arm64}"

# Help function
show_help() {
    echo "Build demo images for Policy Guardrails Demo"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --registry <registry>     Container registry (default: local only)"
    echo "  --image-name <name>       Image name (default: guardian-demo)"
    echo "  --push                    Push images to registry after building"
    echo "  --platform <platforms>   Target platforms (default: linux/amd64,linux/arm64)"
    echo "  --help, -h               Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  REGISTRY                 Container registry"
    echo "  IMAGE_NAME              Image name"
    echo "  PUSH_TO_REGISTRY        Set to 'true' to push images"
    echo "  BUILD_PLATFORM          Target build platforms"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Build locally only"
    echo "  $0 --push                            # Build and push to default registry"
    echo "  $0 --registry local-registry --push  # Build and push to custom registry"
    echo "  REGISTRY=localhost:5000 $0           # Build for local registry"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --push)
            PUSH_TO_REGISTRY="true"
            shift
            ;;
        --platform)
            BUILD_PLATFORM="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Derived variables
if [ -n "$REGISTRY" ]; then
    SECURE_TAG="${REGISTRY}/${IMAGE_NAME}:secure"
    INSECURE_TAG="${REGISTRY}/${IMAGE_NAME}:insecure"
else
    SECURE_TAG="${IMAGE_NAME}:secure"
    INSECURE_TAG="${IMAGE_NAME}:insecure"
fi

echo -e "${CYAN}🔨 Building Policy Guardrails Demo Images (Local)${NC}"
echo -e "${CYAN}==================================================${NC}"
echo "Registry: ${REGISTRY:-local only}"
echo "Image name: $IMAGE_NAME"
echo "Push to registry: $PUSH_TO_REGISTRY"
echo "Build platforms: $BUILD_PLATFORM"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed or not available${NC}"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon is not running${NC}"
    exit 1
fi

# Navigate to the correct directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(dirname "$SCRIPT_DIR")"
cd "$DEMO_DIR"

echo -e "${CYAN}[1/4] Preparing build context${NC}"
# Create images directory if it doesn't exist
mkdir -p images

# Verify Dockerfiles exist
if [ ! -f "images/Dockerfile.secure" ] || [ ! -f "images/Dockerfile.insecure" ]; then
    echo -e "${RED}❌ Dockerfile.secure or Dockerfile.insecure not found in images/ directory${NC}"
    exit 1
fi

echo -e "${CYAN}[2/4] Building secure image${NC}"
echo "Building: $SECURE_TAG"
if [ "$PUSH_TO_REGISTRY" = "true" ]; then
    # Build multi-platform and push
    docker buildx build \
        --platform "$BUILD_PLATFORM" \
        --tag "$SECURE_TAG" \
        --file images/Dockerfile.secure \
        --push \
        .
else
    # Build for local use
    docker build \
        --tag "$SECURE_TAG" \
        --file images/Dockerfile.secure \
        .
fi
echo -e "${GREEN}✅ Secure image built successfully${NC}"

echo -e "${CYAN}[3/4] Building insecure image${NC}"
echo "Building: $INSECURE_TAG"
if [ "$PUSH_TO_REGISTRY" = "true" ]; then
    # Build multi-platform and push
    docker buildx build \
        --platform "$BUILD_PLATFORM" \
        --tag "$INSECURE_TAG" \
        --file images/Dockerfile.insecure \
        --push \
        .
else
    # Build for local use
    docker build \
        --tag "$INSECURE_TAG" \
        --file images/Dockerfile.insecure \
        .
fi
echo -e "${GREEN}✅ Insecure image built successfully${NC}"

echo -e "${CYAN}[4/4] Verification${NC}"
echo "Listing built images:"
docker images | grep "$IMAGE_NAME" || echo "No local images found (may have been pushed only)"

echo ""
echo -e "${GREEN}✅ Image build completed successfully!${NC}"
echo ""
echo "📋 Built images:"
echo "  Secure:   $SECURE_TAG"
echo "  Insecure: $INSECURE_TAG"
echo ""

if [ "$PUSH_TO_REGISTRY" = "true" ]; then
    echo -e "${GREEN}📤 Images pushed to registry: $REGISTRY${NC}"
    echo ""
    echo "To use these images in the demo:"
    echo "  ./scripts/run-demo.sh ${REGISTRY}/${IMAGE_NAME}"
else
    echo -e "${YELLOW}💡 Images built locally only (not pushed to registry)${NC}"
    echo ""
    echo "To push images to registry:"
    echo "  $0 --push"
    echo ""
    echo "To use local images in the demo:"
    echo "  ./scripts/run-demo.sh ${IMAGE_NAME}"
fi

echo ""
echo "🔍 To inspect the images:"
echo "  docker run --rm -it $SECURE_TAG"
echo "  docker run --rm -it $INSECURE_TAG"