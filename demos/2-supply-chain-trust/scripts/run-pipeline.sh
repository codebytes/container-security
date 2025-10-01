#!/bin/bash
# Supply Chain Trust Pipeline - Bash Version
# Demonstrates secure container build with SBOM, scanning, and signing

set -e  # Exit on any error

# Default parameters
REGISTRY="${1:-localhost:5000}"
IMAGE_NAME="${2:-guardian-demo-app}"
TAG="${3:-v0.1.0-secure}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${CYAN}$1${NC}"
}

log_success() {
    echo -e "${GREEN}$1${NC}"
}

log_warning() {
    echo -e "${YELLOW}$1${NC}"
}

log_error() {
    echo -e "${RED}$1${NC}"
}

# Validate required tools
check_tools() {
    log_info "Checking required tools..."
    
    local missing_tools=()
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if ! command -v syft &> /dev/null; then
        missing_tools+=("syft")
    fi
    
    if ! command -v trivy &> /dev/null; then
        missing_tools+=("trivy")
    fi
    
    if ! command -v cosign &> /dev/null; then
        missing_tools+=("cosign")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        exit 1
    fi
    
    log_success "All required tools are available"
}

# Main pipeline
main() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(dirname "$script_dir")"
    local full_image="${REGISTRY}/${IMAGE_NAME}:${TAG}"
    
    log_info "=== Supply Chain Trust Pipeline ==="
    log_info "Registry: $REGISTRY"
    log_info "Image: $IMAGE_NAME"
    log_info "Tag: $TAG"
    log_info "Full Image: $full_image"
    echo
    
    # Change to project root
    cd "$project_root"
    
    # Check tools first
    check_tools
    
    # Ensure attestations directory exists
    mkdir -p attestations
    
    # Step 1: Build image
    log_info "[1/6] Building image $full_image"
    if docker build -f pipeline/Dockerfile -t "$full_image" .; then
        log_success "✅ Image built successfully"
    else
        log_error "❌ Image build failed"
        exit 1
    fi
    echo
    
    # Step 2: Generate SBOM
    log_info "[2/6] Generating SBOM with Syft"
    if syft scan "$full_image" -o json > attestations/sbom.json; then
        local package_count=$(jq '.artifacts[0].packages | length' attestations/sbom.json 2>/dev/null || echo "unknown")
        log_success "✅ SBOM generated successfully ($package_count packages)"
    else
        log_error "❌ SBOM generation failed"
        exit 1
    fi
    echo
    
    # Step 3: Scan for vulnerabilities
    log_info "[3/6] Scanning with Trivy (HIGH,CRITICAL severity threshold)"
    if trivy image --severity HIGH,CRITICAL --exit-code 1 "$full_image"; then
        log_success "✅ No HIGH/CRITICAL vulnerabilities found"
    else
        log_error "❌ HIGH/CRITICAL vulnerabilities found - pipeline blocked"
        log_warning "Fix vulnerabilities before proceeding to production"
        exit 1
    fi
    echo
    
    # Step 4: Push image (optional - may fail without registry credentials)
    log_info "[4/6] Pushing image to registry"
    if docker push "$full_image"; then
        log_success "✅ Image pushed successfully"
    else
        log_warning "⚠️  Image push failed (registry credentials may be required)"
        log_info "Continuing with local signing for demonstration..."
    fi
    echo
    
    # Step 5: Sign image
    log_info "[5/6] Signing image with Cosign"
    if cosign sign "$full_image"; then
        log_success "✅ Image signed successfully"
    else
        log_warning "⚠️  Image signing failed (registry access or keyless auth required)"
        log_info "For demo purposes, you can generate local keys with: cosign generate-key-pair"
    fi
    echo
    
    # Step 6: Verify signature
    log_info "[6/6] Verifying image signature"
    if cosign verify "$full_image"; then
        log_success "✅ Signature verified successfully"
    else
        log_warning "⚠️  Signature verification failed (expected without proper signing setup)"
        log_info "This would work in a properly configured registry environment"
    fi
    echo
    
    log_success "=== Pipeline Completed ==="
    log_info "SBOM stored in: attestations/sbom.json"
    log_info "Next steps:"
    log_info "  1. Review SBOM for dependency analysis"
    log_info "  2. Set up registry credentials for production signing"
    log_info "  3. Deploy Kyverno policies for admission control"
}

# Show usage if help is requested
show_usage() {
    echo "Usage: $0 [REGISTRY] [IMAGE_NAME] [TAG]"
    echo
    echo "Parameters:"
    echo "  REGISTRY    Container registry (default: localhost:5000)"
    echo "  IMAGE_NAME  Image name (default: guardian-demo-app)"
    echo "  TAG         Image tag (default: v0.1.0-secure)"
    echo
    echo "Example:"
    echo "  $0 ghcr.io/myorg my-app v1.0.0"
    echo
    echo "Required tools: docker, syft, trivy, cosign"
}

# Check for help flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_usage
    exit 0
fi

# Run main pipeline
main "$@"