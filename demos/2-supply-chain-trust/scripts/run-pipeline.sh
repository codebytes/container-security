#!/bin/bash
# Supply Chain Trust Pipeline - Bash Version
# Demonstrates secure container build with SBOM, scanning, and signing

set -e  # Exit on any error

# Resolve paths relative to this script so it works from the demo root, scripts/,
# or any other caller CWD.
script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(dirname "$script_dir")"
artifact_dir="$project_root/artifacts"
sbom_path="$artifact_dir/sbom.json"
cosign_key_path="$project_root/cosign.key"
cosign_pub_path="$project_root/cosign.pub"

# Default parameters
# Default to 127.0.0.1:5000 (NOT localhost:5000): on macOS, AirPlay Receiver
# (Control Center / AirTunes) binds *:5000 and localhost resolves to ::1 ->
# AirPlay, returning HTTP 403 for cosign/docker push. 127.0.0.1 hits the local
# registry directly. This is the SAME registry container the shared cluster
# wires up (scripts/setup-kind-cluster.sh publishes it on 127.0.0.1:5000), and
# in-cluster it is reachable as registry:5000. To use localhost instead, either
# disable AirPlay Receiver (System Settings -> General -> AirDrop & Handoff ->
# AirPlay Receiver) or pass it explicitly: ./scripts/run-pipeline.sh localhost:5000
REGISTRY="${1:-127.0.0.1:5000}"
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

print_install_instructions() {
    case "$1" in
        docker)
            log_warning "  docker:"
            echo "    Windows: winget install -e --id Docker.DockerDesktop"
            echo "    macOS:   brew install --cask docker"
            echo "    Manual:  https://docs.docker.com/get-docker/"
            ;;
        kubectl)
            log_warning "  kubectl:"
            echo "    Windows: winget install -e --id Kubernetes.kubectl"
            echo "    macOS:   brew install kubectl"
            echo "    Manual:  https://kubernetes.io/docs/tasks/tools/"
            ;;
        syft)
            log_warning "  syft:"
            echo "    Windows: winget install -e --id Anchore.Syft"
            echo "    macOS:   brew install syft"
            echo "    Manual:  https://github.com/anchore/syft#installation"
            ;;
        trivy)
            log_warning "  trivy:"
            echo "    Windows: winget install -e --id AquaSecurity.Trivy"
            echo "    macOS:   brew install trivy"
            echo "    Manual:  https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
            ;;
        cosign)
            log_warning "  cosign:"
            echo "    Windows: winget install -e --id Sigstore.Cosign"
            echo "    macOS:   brew install cosign"
            echo "    Manual:  https://docs.sigstore.dev/cosign/installation/"
            ;;
    esac
}

# cosign 3.0.6 defaults to --use-signing-config=true / --new-bundle-format=true,
# which stores the signature as an OCI 1.1 referrer (tag sha256-<digest>) instead
# of the legacy sha256-<digest>.sig that Kyverno's verifyImages reader expects ->
# Kyverno reports "no signatures found" and rejects EVERYTHING. Force the legacy
# format so the signature round-trips through cosign verify AND Kyverno. Each flag
# is only added if the installed cosign supports it (guards older cosign 2.x that
# lacks --use-signing-config / --new-bundle-format), per the version-pin note.
cosign_supports() { cosign "$1" --help 2>/dev/null | grep -q -- "$2"; }

cosign_sign_flags() {
    local flags=(--yes --allow-http-registry)
    cosign_supports sign "--use-signing-config" && flags+=(--use-signing-config=false)
    cosign_supports sign "--new-bundle-format"  && flags+=(--new-bundle-format=false)
    cosign_supports sign "--tlog-upload"         && flags+=(--tlog-upload=false)
    printf '%s\n' "${flags[@]}"
}

cosign_verify_flags() {
    local flags=(--allow-http-registry)
    cosign_supports verify "--insecure-ignore-tlog" && flags+=(--insecure-ignore-tlog=true)
    printf '%s\n' "${flags[@]}"
}

# Validate required tools and key material before any pipeline work starts.
check_tools() {
    local missing_tools=()
    local tool

    for tool in docker kubectl syft trivy cosign; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        for tool in "${missing_tools[@]}"; do
            log_error "ERROR: missing prerequisite: $tool"
        done
        echo
        log_info "Install the missing tool(s), then rerun this pipeline:"
        for tool in "${missing_tools[@]}"; do
            print_install_instructions "$tool"
        done
    fi

    if [ ! -f "$cosign_key_path" ]; then
        log_error "ERROR: missing prerequisite: cosign.key"
        log_info "Generate a local key pair from the demo root:"
        echo "  cd \"$project_root\""
        echo "  cosign generate-key-pair"
        echo "This creates cosign.key (private, gitignored) and cosign.pub (public)."
        missing_tools+=("cosign.key")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        exit 1
    fi

    log_success "All required tools and cosign.key are available"
}

# Ensure a local registry is available when targeting localhost so `docker push`
# works out of the box. Prefer REUSING the registry created/wired by
# scripts/setup-kind-cluster.sh (same container name `registry`, host port 5000)
# so signed images are reachable from the kind cluster at admission. Only fall
# back to a standalone registry if none exists.
start_registry() {
    if [[ "$REGISTRY" == localhost:* || "$REGISTRY" == 127.0.0.1:* ]]; then
        local port="${REGISTRY##*:}"
        if docker ps --format '{{.Names}}' | grep -q '^registry$'; then
            if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' registry 2>/dev/null)" != 'null' ]; then
                log_info "Reusing kind-network registry ($REGISTRY) — images are reachable from the kind cluster"
            else
                log_info "Reusing existing local registry ($REGISTRY)"
                log_warning "⚠️  This registry is NOT on the kind network; images won't pull from a kind cluster."
                log_warning "    Run scripts/setup-kind-cluster.sh first for end-to-end admission verification."
            fi
        else
            log_warning "No shared registry found; starting a standalone registry on $REGISTRY"
            log_warning "⚠️  A standalone registry is NOT reachable from a kind cluster's nodes."
            log_warning "    For demo 5 / signed-image admission, run scripts/setup-kind-cluster.sh instead."
            docker run -d -p "${port}:5000" --name registry registry:2 >/dev/null
            log_success "✅ Local registry started on $REGISTRY"
        fi
    fi
}

# Main pipeline
main() {
    local full_image="${REGISTRY}/${IMAGE_NAME}:${TAG}"
    
    log_info "=== Supply Chain Trust Pipeline ==="
    log_info "Registry: $REGISTRY"
    log_info "Image: $IMAGE_NAME"
    log_info "Tag: $TAG"
    log_info "Full Image: $full_image"
    echo
    
    # Change to project root resolved from this script's location.
    cd "$project_root"
    
    # Check tools and key material before doing any work.
    check_tools

    # Bootstrap a local registry if needed so docker push succeeds
    start_registry

    # Ensure generated artifacts directory exists (gitignored).
    mkdir -p "$artifact_dir"
    
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
    if syft scan "$full_image" -o json > "$sbom_path"; then
        local package_count=$(jq '.artifacts[0].packages | length' "$sbom_path" 2>/dev/null || echo "unknown")
        log_success "✅ SBOM generated successfully ($package_count packages)"
    else
        log_error "❌ SBOM generation failed"
        exit 1
    fi
    echo
    
    # Step 3: Scan for vulnerabilities
    #
    # By default this gate is INFORMATIONAL and does NOT hard-block the demo.
    # Rationale: with a live Trivy DB, every practical base image (including the
    # distroless final stage used here) reports some unfixed base-OS HIGH/CRITICAL
    # CVEs (e.g. zlib `will_not_fix`). A hard `--exit-code 1` gate would
    # permanently dead-end the demo before the sign/verify/admission story can run.
    # Set STRICT_SCAN=1 to restore a hard, production-style gate.
    if [ "${STRICT_SCAN:-0}" = "1" ]; then
        log_info "[3/6] Scanning with Trivy (HIGH,CRITICAL) — STRICT gate (STRICT_SCAN=1)"
        if trivy image --severity HIGH,CRITICAL --exit-code 1 "$full_image"; then
            log_success "✅ No HIGH/CRITICAL vulnerabilities found"
        else
            log_error "❌ HIGH/CRITICAL vulnerabilities found - pipeline blocked (STRICT_SCAN=1)"
            log_warning "Fix vulnerabilities before proceeding to production"
            exit 1
        fi
    else
        log_info "[3/6] Scanning with Trivy (HIGH,CRITICAL) — INFORMATIONAL (set STRICT_SCAN=1 to enforce)"
        trivy image --severity HIGH,CRITICAL "$full_image" || true
        log_warning "ℹ️  Scan is informational: findings above do NOT block this demo."
        log_info "    The distroless base minimizes surface; remaining items are mostly unfixed base-OS CVEs."
        log_info "    Wire STRICT_SCAN=1 (or your own risk policy) to gate in production CI."
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
    
    # Step 5: Sign image (keyed)
    # cosign signs the image DIGEST, not the tag. Resolve the pushed digest so the
    # signature attaches to the exact manifest Kyverno will admit, and to avoid the
    # tag-vs-digest cosign warning.
    log_info "[5/6] Signing image with Cosign (keyed)"
    local sign_ref="$full_image"
    local repo_digest
    repo_digest="$(docker inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$full_image" 2>/dev/null | grep "^${REGISTRY}/${IMAGE_NAME}@" | head -1 || true)"
    if [ -n "$repo_digest" ]; then
        sign_ref="$repo_digest"
        log_info "      Signing digest: $sign_ref"
    fi
    # --allow-http-registry: the local kind/standalone registry serves plain HTTP.
    # Legacy bundle format (see cosign_sign_flags) so Kyverno can find the .sig.
    # Flags are simple tokens (no spaces) so word-splitting into an array is safe
    # and avoids bash-4-only `mapfile` (macOS ships bash 3.2).
    local sign_flags
    # shellcheck disable=SC2207
    sign_flags=( $(cosign_sign_flags) )
    if COSIGN_PASSWORD="${COSIGN_PASSWORD-}" cosign sign "${sign_flags[@]}" --key "$cosign_key_path" "$sign_ref"; then
        log_success "✅ Image signed successfully (legacy .sig format — Kyverno-compatible)"
    else
        log_warning "⚠️  Image signing failed (registry access or cosign.key required)"
        log_info "For demo purposes, you can generate local keys with: cosign generate-key-pair"
    fi
    echo
    
    # Step 6: Verify signature (keyed)
    log_info "[6/6] Verifying image signature (keyed)"
    local verify_flags
    # shellcheck disable=SC2207
    verify_flags=( $(cosign_verify_flags) )
    if cosign verify "${verify_flags[@]}" --key "$cosign_pub_path" "$sign_ref"; then
        log_success "✅ Signature verified successfully"
    else
        log_warning "⚠️  Signature verification failed (expected without proper signing setup)"
        log_info "This would work in a properly configured registry environment"
    fi
    echo
    
    log_success "=== Pipeline Completed ==="
    log_info "SBOM stored in: artifacts/sbom.json"
    log_info "Next step — run the in-cluster admission demo (signed ADMITTED vs unsigned REJECTED)"
    log_info "fully automatically (enables Kyverno insecure-registry access, injects the public"
    log_info "key, applies the policy, deploys signed, builds+deploys a DISTINCT unsigned image):"
    log_info "       ./scripts/setup-admission.sh ${REGISTRY} ${IMAGE_NAME} ${TAG}"
    log_info "Tear it down with: ./scripts/cleanup.sh"
}

# Show usage if help is requested
show_usage() {
    echo "Usage: $0 [REGISTRY] [IMAGE_NAME] [TAG]"
    echo
    echo "Parameters:"
    echo "  REGISTRY    Container registry (default: 127.0.0.1:5000)"
    echo "  IMAGE_NAME  Image name (default: guardian-demo-app)"
    echo "  TAG         Image tag (default: v0.1.0-secure)"
    echo
    echo "Example:"
    echo "  $0 ghcr.io/myorg my-app v1.0.0"
    echo
    echo "Required tools: docker, kubectl, syft, trivy, cosign"
    echo "Required key: cosign.key in the demo root (run: cosign generate-key-pair)"
}

# Check for help flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_usage
    exit 0
fi

# Run main pipeline
main "$@"
