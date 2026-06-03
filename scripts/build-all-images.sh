#!/bin/bash
# Container Security Demos - Docker Hub Build & Push Script
# Builds and pushes all demo images to Docker Hub registry

set -e

# Configuration
DOCKER_REGISTRY="${DOCKER_REGISTRY:-codebytes}"
TAG="${TAG:-latest}"
VERSION="${VERSION:-v1.0.0}"
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    log_success "Docker is available and running"
}

# Docker login check
check_docker_login() {
    log_info "Checking Docker Hub authentication..."
    if ! docker info | grep -q "Username"; then
        log_warning "Not logged into Docker Hub. Please run: docker login"
        log_info "After login, re-run this script."
        read -p "Do you want to login now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker login
        else
            exit 1
        fi
    fi
    log_success "Docker Hub authentication verified"
}

# Build a single image
build_image() {
    local dockerfile="$1"
    local image_name="$2"
    local context_dir="$3"
    local full_image="${DOCKER_REGISTRY}/${image_name}:${TAG}"
    local version_image="${DOCKER_REGISTRY}/${image_name}:${VERSION}"

    log_info "Building ${image_name}..."
    log_info "  Dockerfile: ${dockerfile}"
    log_info "  Context: ${context_dir}"
    log_info "  Image: ${full_image}"

    if docker build \
        --file "${dockerfile}" \
        --tag "${full_image}" \
        --tag "${version_image}" \
        --label "org.opencontainers.image.title=${image_name}" \
        --label "org.opencontainers.image.description=Container Security Demo Image" \
        --label "org.opencontainers.image.vendor=codebytes" \
        --label "org.opencontainers.image.created=${BUILD_DATE}" \
        --label "org.opencontainers.image.revision=${GIT_COMMIT}" \
        --label "org.opencontainers.image.version=${VERSION}" \
        --label "org.opencontainers.image.source=https://github.com/codebytes/container-security" \
        "${context_dir}"; then
        log_success "✅ Built ${image_name}"
        return 0
    else
        log_error "❌ Failed to build ${image_name}"
        return 1
    fi
}

# Push a single image
push_image() {
    local image_name="$1"
    local full_image="${DOCKER_REGISTRY}/${image_name}:${TAG}"
    local version_image="${DOCKER_REGISTRY}/${image_name}:${VERSION}"

    log_info "Pushing ${image_name}..."

    if docker push "${full_image}" && docker push "${version_image}"; then
        log_success "✅ Pushed ${image_name}"
        log_info "  Available at: https://hub.docker.com/r/${DOCKER_REGISTRY}/${image_name}"
        return 0
    else
        log_error "❌ Failed to push ${image_name}"
        return 1
    fi
}

# Build and push all images
build_all() {
    local project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    cd "$project_root"

    log_info "🚀 Container Security Demos - Docker Hub Build & Push"
    log_info "=================================================="
    log_info "Registry: ${DOCKER_REGISTRY}"
    log_info "Tag: ${TAG}"
    log_info "Version: ${VERSION}"
    log_info "Build Date: ${BUILD_DATE}"
    log_info "Git Commit: ${GIT_COMMIT}"
    echo

    local images_built=()
    local images_failed=()

    # Demo 1: Policy Guardrails Images
    log_info "📋 Building Demo 1: Policy Guardrails Images"
    if build_image "demos/1-policy-guardrails/images/Dockerfile.secure" "guardian-demo-secure" "demos/1-policy-guardrails"; then
        images_built+=("guardian-demo-secure")
    else
        images_failed+=("guardian-demo-secure")
    fi

    if build_image "demos/1-policy-guardrails/images/Dockerfile.insecure" "guardian-demo-insecure" "demos/1-policy-guardrails"; then
        images_built+=("guardian-demo-insecure")
    else
        images_failed+=("guardian-demo-insecure")
    fi

    # Demo 2: Supply Chain Trust
    log_info "🔒 Building Demo 2: Supply Chain Trust"
    if build_image "demos/2-supply-chain-trust/pipeline/Dockerfile" "guardian-demo-app" "demos/2-supply-chain-trust"; then
        images_built+=("guardian-demo-app")
    else
        images_failed+=("guardian-demo-app")
    fi

    # Demo 3: Image Hardening
    log_info "🛡️ Building Demo 3: Image Hardening Images"
    if build_image "demos/3-image-hardening/dockerfiles/Dockerfile.before" "guardian-demo-vulnerable" "demos/3-image-hardening"; then
        images_built+=("guardian-demo-vulnerable")
    else
        images_failed+=("guardian-demo-vulnerable")
    fi

    if build_image "demos/3-image-hardening/dockerfiles/Dockerfile.after" "guardian-demo-hardened" "demos/3-image-hardening"; then
        images_built+=("guardian-demo-hardened")
    else
        images_failed+=("guardian-demo-hardened")
    fi

    # Demo 6: Observability Signals
    log_info "📊 Building Demo 6: Observability Signals"
    if build_image "demos/6-observability-signals/app/Dockerfile" "guardian-telemetry" "demos/6-observability-signals/app"; then
        images_built+=("guardian-telemetry")
    else
        images_failed+=("guardian-telemetry")
    fi

    # Source images
    log_info "🏗️ Building Source Images"
    if build_image "src/Dockerfile" "guardian-demo" "src"; then
        images_built+=("guardian-demo")
    else
        images_failed+=("guardian-demo")
    fi

    if build_image "src/Dockerfile.insecure" "guardian-demo-base-insecure" "src"; then
        images_built+=("guardian-demo-base-insecure")
    else
        images_failed+=("guardian-demo-base-insecure")
    fi

    echo
    log_info "📦 Build Summary"
    log_success "Successfully built: ${#images_built[@]} images"
    for image in "${images_built[@]}"; do
        echo "  ✅ ${image}"
    done

    if [ ${#images_failed[@]} -gt 0 ]; then
        log_error "Failed to build: ${#images_failed[@]} images"
        for image in "${images_failed[@]}"; do
            echo "  ❌ ${image}"
        done
    fi

    # Push images if builds were successful
    if [ ${#images_built[@]} -gt 0 ]; then
        echo
        log_info "🚀 Pushing images to Docker Hub..."
        local pushed_count=0

        for image in "${images_built[@]}"; do
            if push_image "$image"; then
                ((pushed_count++))
            fi
        done

        echo
        log_success "🎉 Build and Push Complete!"
        log_info "Pushed ${pushed_count}/${#images_built[@]} images to Docker Hub"
        log_info "Visit: https://hub.docker.com/u/${DOCKER_REGISTRY}"
    else
        log_error "No images to push due to build failures"
        exit 1
    fi
}

# Show usage information
show_usage() {
    echo "Container Security Demos - Docker Hub Build & Push Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --registry REGISTRY    Docker registry (default: codebytes)"
    echo "  --tag TAG             Image tag (default: latest)"
    echo "  --version VERSION     Version tag (default: v1.0.0)"
    echo "  --help, -h            Show this help message"
    echo
    echo "Environment Variables:"
    echo "  DOCKER_REGISTRY       Override default registry"
    echo "  TAG                   Override default tag"
    echo "  VERSION               Override default version"
    echo
    echo "Examples:"
    echo "  $0                                    # Build with defaults"
    echo "  $0 --registry myregistry --tag dev   # Custom registry and tag"
    echo "  TAG=v2.0.0 $0                        # Custom version via env var"
    echo
    echo "Before running:"
    echo "  docker login                          # Login to Docker Hub"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --registry)
            DOCKER_REGISTRY="$2"
            shift 2
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    check_docker
    check_docker_login
    build_all
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi