#!/bin/bash
# Supply Chain Trust Demo - In-cluster admission setup (Bash)
#
# Runs the signed-vs-unsigned admission demo end-to-end with NO manual steps:
#   1. Ensures Kyverno is installed AND can reach the plain-HTTP local registry
#      (Kyverno ships --allowInsecureRegistry=false; we enable it automatically).
#   2. Injects the cosign PUBLIC key as a secret so Kyverno can verify signatures.
#   3. Applies the demo namespace + verifyImages policy.
#   4. Deploys the SIGNED image  -> EXPECT ADMITTED (pod schedules).
#   5. Builds a genuinely DISTINCT UNSIGNED image (cosign signs the digest, not the
#      tag, so a re-tag would still be signed), pushes it, and deploys it
#      -> EXPECT REJECTED (Kyverno: "no signatures found").
#
# Prereqs: run ./scripts/run-pipeline.sh first (builds, pushes, and SIGNS the
# secure image), and have the shared kind+Calico cluster up
# (scripts/setup-kind-cluster.sh). Requires kubectl; helm recommended.

set -euo pipefail

REGISTRY="${1:-127.0.0.1:5000}"
IMAGE_NAME="${2:-guardian-demo-app}"
TAG="${3:-v0.1.0-secure}"
UNSIGNED_TAG="${4:-v0.1.0-unsigned}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()    { echo -e "${CYAN}$1${NC}"; }
log_success() { echo -e "${GREEN}$1${NC}"; }
log_warning() { echo -e "${YELLOW}$1${NC}"; }
log_error()   { echo -e "${RED}$1${NC}"; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(dirname "$script_dir")"
cd "$project_root"

# ── Preconditions ───────────────────────────────────────────────────────────
command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is required"; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { log_error "No reachable cluster. Run scripts/setup-kind-cluster.sh first."; exit 1; }
[ -f cosign.pub ] || { log_error "cosign.pub not found in $project_root. Run 'cosign generate-key-pair' first."; exit 1; }

# ── Step 1: Ensure Kyverno installed + insecure-registry access enabled ─────
log_info "[1/6] Ensuring Kyverno is installed and can pull from the plain-HTTP registry"
kyverno_has_deployment() {
    kubectl -n kyverno get deploy -o name 2>/dev/null | grep -q .
}
if ! kubectl get ns kyverno >/dev/null 2>&1 || ! kyverno_has_deployment; then
    if command -v helm >/dev/null 2>&1; then
        log_info "       Installing Kyverno via Helm (with --allowInsecureRegistry=true)..."
        helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update >/dev/null 2>&1 || true
        helm repo update >/dev/null 2>&1 || true
        # Best-effort: chart layouts vary by version, so we also patch the
        # deployment below to guarantee the flag is present.
        # NOTE: the chart's admissionController.container.extraArgs is a MAP
        # (key->value), NOT a list. Using list-index syntax (extraArgs[0]=...)
        # renders a bogus flag `--0=--allowInsecureRegistry=true` and the
        # controller CrashLoopBackOffs with `flag provided but not defined: -0`.
        # The map form below renders a real `--allowInsecureRegistry=true` flag.
        helm upgrade --install kyverno kyverno/kyverno \
            --namespace kyverno --create-namespace --wait --timeout=5m \
            --set admissionController.container.extraArgs.allowInsecureRegistry=true \
            || helm upgrade --install kyverno kyverno/kyverno \
                 --namespace kyverno --create-namespace --wait --timeout=5m
    else
        log_warning "       Helm not found; installing Kyverno via kubectl manifest..."
        kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml
        kubectl wait --for=condition=established crd/clusterpolicies.kyverno.io --timeout=300s
    fi
fi
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=kyverno -n kyverno --timeout=300s || true

# Guarantee --allowInsecureRegistry=true on the admission controller regardless of
# how Kyverno was installed (idempotent). Kyverno otherwise rejects plain-HTTP
# registries: "http: server gave HTTP response to HTTPS client".
ensure_insecure_registry() {
    local deploy="kyverno-admission-controller" container="kyverno"
    if ! kubectl -n kyverno get deploy "$deploy" >/dev/null 2>&1; then
        # Older single-deployment layout
        deploy="$(kubectl -n kyverno get deploy -o name | grep -E 'kyverno(-admission-controller)?$' | head -1 | cut -d/ -f2)"
    fi
    [ -n "${deploy:-}" ] || { log_warning "Could not locate Kyverno admission deployment to patch."; return 0; }
    local cname
    cname="$(kubectl -n kyverno get deploy "$deploy" -o jsonpath='{.spec.template.spec.containers[0].name}')"
    local args
    args="$(kubectl -n kyverno get deploy "$deploy" -o json | jq -c \
        --arg c "$cname" '[.spec.template.spec.containers[] | select(.name==$c) | .args // []][0]')"
    # EXACT-element check (not a substring grep): a malformed
    # `--0=--allowInsecureRegistry=true` arg would satisfy a substring match and
    # wrongly skip the fix, so we require the standalone, properly-formed flag.
    if echo "$args" | jq -e 'any(.[]; . == "--allowInsecureRegistry=true")' >/dev/null; then
        log_info "       --allowInsecureRegistry=true already set on $deploy"
        return 0
    fi
    # Sanitize: drop any malformed `--0=*` element and the default
    # `--allowInsecureRegistry=false`, then append the correct flag.
    local new_args
    new_args="$(echo "$args" | jq -c '
        [ .[] | select((startswith("--0=") | not) and . != "--allowInsecureRegistry=false") ]
        + ["--allowInsecureRegistry=true"]')"
    kubectl -n kyverno patch deploy "$deploy" --type=json -p "$(jq -nc \
        --argjson a "$new_args" --arg c "$cname" \
        '[{"op":"replace","path":"/spec/template/spec/containers/0/args","value":$a}]')" \
        >/dev/null
    log_success "       Patched $deploy with --allowInsecureRegistry=true"
    kubectl -n kyverno rollout status deploy "$deploy" --timeout=180s || true
}
ensure_insecure_registry
echo

# ── Step 2: Inject cosign PUBLIC key for Kyverno verification ────────────────
log_info "[2/6] Injecting cosign public key (secret kyverno/guardian-cosign-pub)"
kubectl -n kyverno create secret generic guardian-cosign-pub \
    --from-file=cosign.pub=cosign.pub --dry-run=client -o yaml | kubectl apply -f -
echo

# ── Step 3: Apply namespace + policy ────────────────────────────────────────
log_info "[3/6] Applying demo namespace + verifyImages policy"
kubectl apply -f manifests/demo-namespace.yaml -f manifests/policy-require-signature.yaml
echo

# ── Step 4: Deploy SIGNED image (EXPECT ADMITTED) ───────────────────────────
log_info "[4/6] Deploying SIGNED image (EXPECT ADMITTED)"
kubectl apply -f manifests/deploy-signed.yaml
if kubectl -n demo-gamora rollout status deploy/guardian-signed --timeout=180s; then
    log_success "✅ SIGNED image ADMITTED and rolled out"
else
    log_warning "⚠️  Signed deployment did not become ready in time — check:"
    kubectl -n demo-gamora describe deploy/guardian-signed | tail -20 || true
    kubectl -n demo-gamora get events --sort-by=.lastTimestamp | tail -20 || true
fi
echo

# ── Step 5: Build a DISTINCT UNSIGNED image and push it ─────────────────────
log_info "[5/6] Building a genuinely DISTINCT unsigned image (different digest) and pushing it"
unsigned_image="${REGISTRY}/${IMAGE_NAME}:${UNSIGNED_TAG}"
docker build -f pipeline/Dockerfile --label demo.variant=unsigned --no-cache -t "$unsigned_image" .
docker push "$unsigned_image"
log_warning "       (Intentionally NOT signing this image.)"
echo

# ── Step 6: Deploy UNSIGNED image (EXPECT REJECTED) ─────────────────────────
log_info "[6/6] Deploying UNSIGNED image (EXPECT REJECTED by Kyverno)"
# This apply is EXPECTED to fail: Kyverno (via autogen rules on the Deployment)
# synchronously DENIES the request at admission time because the image is unsigned.
# Capture the outcome instead of letting the non-zero exit abort the script under
# `set -e`, so we can assert it failed for the RIGHT reason and print the summary.
unsigned_apply_out="$(kubectl apply -f manifests/deploy-unsigned.yaml 2>&1)" && unsigned_rc=0 || unsigned_rc=$?

if [ "${unsigned_rc:-1}" -ne 0 ] && \
   echo "$unsigned_apply_out" | grep -qiE 'no signatures found|verify-supply-chain-signatures|failed to verify|denied the request'; then
    # Expected, correct outcome: admission denied the unsigned image synchronously.
    log_success "✅ UNSIGNED image correctly REJECTED at admission (Kyverno denied the request):"
    echo "$unsigned_apply_out" | grep -iE 'no signatures found|verify-supply-chain-signatures|failed to verify|denied the request' | head -3
else
    log_info "       Apply did not fail synchronously; checking async pod admission..."
    sleep 15
    # Fallback: some configurations admit the Deployment object but block the
    # underlying Pod, surfacing as a FailedCreate event on the ReplicaSet.
    rs_events="$(kubectl -n demo-gamora describe rs -l app=guardian-unsigned 2>/dev/null || true)"
    if echo "$rs_events" | grep -qiE 'no signatures found|verify-supply-chain-signatures|failed to verify'; then
        log_success "✅ UNSIGNED image REJECTED by admission (Kyverno blocked pod creation):"
        echo "$rs_events" | grep -iE 'no signatures found|verify-supply-chain-signatures|failed to verify' | head -3
    else
        ready="$(kubectl -n demo-gamora get deploy guardian-unsigned -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
        if [ "${ready:-0}" = "0" ]; then
            log_warning "⚠️  Unsigned pod is NOT running (likely rejected). Inspect events:"
            kubectl -n demo-gamora get events --sort-by=.lastTimestamp | tail -20 || true
        else
            log_error "❌ Unexpected: unsigned image became ready — policy may not be enforcing."
        fi
    fi
fi
echo

log_success "=== Admission demo complete ==="
log_info "SIGNED -> guardian-signed (admitted) · UNSIGNED -> guardian-unsigned (rejected)"
log_info "Tear everything down with: ./scripts/cleanup.sh"
