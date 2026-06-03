#requires -Version 7.0
<#
.SYNOPSIS
    Supply Chain Trust Demo - In-cluster admission setup (PowerShell twin of setup-admission.sh).

.DESCRIPTION
    Runs the signed-vs-unsigned admission demo end-to-end with NO manual steps:
      1. Ensures Kyverno is installed AND can reach the plain-HTTP local registry
         (Kyverno ships --allowInsecureRegistry=false; we enable it automatically).
      2. Injects the cosign PUBLIC key as a secret so Kyverno can verify signatures.
      3. Applies the demo namespace + verifyImages policy.
      4. Deploys the SIGNED image  -> EXPECT ADMITTED.
      5. Builds a genuinely DISTINCT UNSIGNED image, pushes it, deploys it
         -> EXPECT REJECTED (Kyverno: "no signatures found").

    Prereqs: run ./scripts/run-pipeline.ps1 first (builds/pushes/SIGNS the secure
    image) and have the shared kind+Calico cluster up. Requires kubectl; helm recommended.
#>
param(
    [string]$Registry = "127.0.0.1:5000",
    [string]$ImageName = "guardian-demo-app",
    [string]$Tag = "v0.1.0-secure",
    [string]$UnsignedTag = "v0.1.0-unsigned"
)

$ErrorActionPreference = 'Stop'
$scriptDir   = $PSScriptRoot
$projectRoot = Split-Path -Parent $scriptDir
Set-Location $projectRoot

# ── Preconditions ───────────────────────────────────────────────────────────
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { Write-Error "kubectl is required"; exit 1 }
kubectl cluster-info *> $null
if ($LASTEXITCODE -ne 0) { Write-Error "No reachable cluster. Run scripts/setup-kind-cluster.ps1 first."; exit 1 }
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'cosign.pub'))) {
    Write-Error "cosign.pub not found in $projectRoot. Run 'cosign generate-key-pair' first."; exit 1
}

# ── Step 1: Ensure Kyverno installed + insecure-registry access enabled ─────
Write-Host "[1/6] Ensuring Kyverno is installed and can pull from the plain-HTTP registry" -ForegroundColor Cyan
$kyvernoPresent = $false
kubectl get ns kyverno *> $null
if ($LASTEXITCODE -eq 0) {
    kubectl -n kyverno get deploy *> $null
    if ($LASTEXITCODE -eq 0) { $kyvernoPresent = $true }
}
if (-not $kyvernoPresent) {
    if (Get-Command helm -ErrorAction SilentlyContinue) {
        Write-Host "       Installing Kyverno via Helm (with --allowInsecureRegistry=true)..."
        helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update *> $null
        helm repo update *> $null
        # NOTE: the chart's admissionController.container.extraArgs is a MAP, NOT
        # a list. List-index syntax (extraArgs[0]=...) renders a bogus flag
        # `--0=--allowInsecureRegistry=true` and the controller CrashLoopBackOffs
        # (`flag provided but not defined: -0`). The map form renders a real flag.
        helm upgrade --install kyverno kyverno/kyverno `
            --namespace kyverno --create-namespace --wait --timeout=5m `
            --set 'admissionController.container.extraArgs.allowInsecureRegistry=true'
        if ($LASTEXITCODE -ne 0) {
            helm upgrade --install kyverno kyverno/kyverno `
                --namespace kyverno --create-namespace --wait --timeout=5m
        }
    } else {
        Write-Host "       Helm not found; installing Kyverno via kubectl manifest..." -ForegroundColor Yellow
        kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml
        kubectl wait --for=condition=established crd/clusterpolicies.kyverno.io --timeout=300s
    }
}
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=kyverno -n kyverno --timeout=300s 2>$null | Out-Null

# Guarantee --allowInsecureRegistry=true on the admission controller (idempotent).
function Set-InsecureRegistry {
    $deploy = 'kyverno-admission-controller'
    kubectl -n kyverno get deploy $deploy *> $null
    if ($LASTEXITCODE -ne 0) {
        $deploy = (kubectl -n kyverno get deploy -o name |
            Select-String -Pattern 'kyverno(-admission-controller)?$' |
            Select-Object -First 1) -replace '^deployment\.apps/',''
    }
    if (-not $deploy) { Write-Host "Could not locate Kyverno admission deployment to patch." -ForegroundColor Yellow; return }
    $json = kubectl -n kyverno get deploy $deploy -o json | ConvertFrom-Json
    $container = $json.spec.template.spec.containers[0]
    $ctrArgs = @()
    if ($container.args) { $ctrArgs = @($container.args) }
    # EXACT-element check (not a substring match): a malformed
    # '--0=--allowInsecureRegistry=true' arg must NOT count as already-set.
    if ($ctrArgs -contains '--allowInsecureRegistry=true') {
        Write-Host "       --allowInsecureRegistry=true already set on $deploy"
        return
    }
    # Sanitize: drop any malformed '--0=*' element and the default
    # '--allowInsecureRegistry=false', then append the correct flag.
    $ctrArgs = @($ctrArgs | Where-Object { ($_ -notlike '--0=*') -and ($_ -ne '--allowInsecureRegistry=false') })
    $ctrArgs += '--allowInsecureRegistry=true'
    $patch = @(@{ op = 'replace'; path = '/spec/template/spec/containers/0/args'; value = $ctrArgs }) | ConvertTo-Json -Depth 6 -Compress
    kubectl -n kyverno patch deploy $deploy --type=json -p $patch | Out-Null
    Write-Host "       Patched $deploy with --allowInsecureRegistry=true" -ForegroundColor Green
    kubectl -n kyverno rollout status deploy $deploy --timeout=180s 2>$null | Out-Null
}
Set-InsecureRegistry
Write-Host ""

# ── Step 2: Inject cosign PUBLIC key for Kyverno verification ────────────────
Write-Host "[2/6] Injecting cosign public key (secret kyverno/guardian-cosign-pub)" -ForegroundColor Cyan
kubectl -n kyverno create secret generic guardian-cosign-pub `
    --from-file=cosign.pub=cosign.pub --dry-run=client -o yaml | kubectl apply -f -
Write-Host ""

# ── Step 3: Apply namespace + policy ────────────────────────────────────────
Write-Host "[3/6] Applying demo namespace + verifyImages policy" -ForegroundColor Cyan
kubectl apply -f manifests/demo-namespace.yaml -f manifests/policy-require-signature.yaml
Write-Host ""

# ── Step 4: Deploy SIGNED image (EXPECT ADMITTED) ───────────────────────────
Write-Host "[4/6] Deploying SIGNED image (EXPECT ADMITTED)" -ForegroundColor Cyan
kubectl apply -f manifests/deploy-signed.yaml
kubectl -n demo-gamora rollout status deploy/guardian-signed --timeout=180s
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ SIGNED image ADMITTED and rolled out" -ForegroundColor Green
} else {
    Write-Host "⚠️  Signed deployment did not become ready in time — check events." -ForegroundColor Yellow
    kubectl -n demo-gamora get events --sort-by=.lastTimestamp
}
Write-Host ""

# ── Step 5: Build a DISTINCT UNSIGNED image and push it ─────────────────────
Write-Host "[5/6] Building a genuinely DISTINCT unsigned image (different digest) and pushing it" -ForegroundColor Cyan
$unsignedImage = "${Registry}/${ImageName}:${UnsignedTag}"
docker build -f pipeline/Dockerfile --label demo.variant=unsigned --no-cache -t $unsignedImage .
docker push $unsignedImage
Write-Host "       (Intentionally NOT signing this image.)" -ForegroundColor Yellow
Write-Host ""

# ── Step 6: Deploy UNSIGNED image (EXPECT REJECTED) ─────────────────────────
Write-Host "[6/6] Deploying UNSIGNED image (EXPECT REJECTED by Kyverno)" -ForegroundColor Cyan
# This apply is EXPECTED to fail: Kyverno (via autogen rules on the Deployment)
# synchronously DENIES the request at admission time because the image is unsigned.
# Capture the outcome instead of letting the non-zero exit abort the script under
# `$ErrorActionPreference = 'Stop'`, so we can assert it failed for the RIGHT reason.
$unsignedApplyOut = ''
try {
    $unsignedApplyOut = (kubectl apply -f manifests/deploy-unsigned.yaml 2>&1 | Out-String)
} catch {
    $unsignedApplyOut = ($_ | Out-String)
}
$unsignedRc = $LASTEXITCODE

if ($unsignedRc -ne 0 -and $unsignedApplyOut -match 'no signatures found|verify-supply-chain-signatures|failed to verify|denied the request') {
    # Expected, correct outcome: admission denied the unsigned image synchronously.
    Write-Host "✅ UNSIGNED image correctly REJECTED at admission (Kyverno denied the request):" -ForegroundColor Green
    ($unsignedApplyOut -split "`n" | Select-String -Pattern 'no signatures found|verify-supply-chain-signatures|failed to verify|denied the request' | Select-Object -First 3) | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "       Apply did not fail synchronously; checking async pod admission..."
    Start-Sleep -Seconds 15
    $rsEvents = (kubectl -n demo-gamora describe rs -l app=guardian-unsigned 2>$null | Out-String)
    if ($rsEvents -match 'no signatures found|verify-supply-chain-signatures|failed to verify') {
        Write-Host "✅ UNSIGNED image REJECTED by admission (Kyverno blocked pod creation)" -ForegroundColor Green
    } else {
        $ready = (kubectl -n demo-gamora get deploy guardian-unsigned -o jsonpath='{.status.readyReplicas}' 2>$null)
        if (-not $ready -or $ready -eq '0') {
            Write-Host "⚠️  Unsigned pod is NOT running (likely rejected). Inspect events:" -ForegroundColor Yellow
            kubectl -n demo-gamora get events --sort-by=.lastTimestamp
        } else {
            Write-Host "❌ Unexpected: unsigned image became ready — policy may not be enforcing." -ForegroundColor Red
        }
    }
}
Write-Host ""

Write-Host "=== Admission demo complete ===" -ForegroundColor Green
Write-Host "SIGNED -> guardian-signed (admitted) · UNSIGNED -> guardian-unsigned (rejected)"
Write-Host "Tear everything down with: ./scripts/cleanup.ps1"
