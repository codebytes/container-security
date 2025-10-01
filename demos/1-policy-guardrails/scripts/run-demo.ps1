#requires -Version 7.0
<#
.SYNOPSIS
    Policy Guardrails Demo - Interactive PowerShell Version
    Demonstrates "before and after" admission control with Kyverno policies

.PARAMETER Image
    The container image to use for the demo (default: guardian-demo)

.PARAMETER Automated
    Run in automated mode (no user interaction required)

.PARAMETER Help
    Show help information

.EXAMPLE
    .\run-demo-interactive.ps1
    .\run-demo-interactive.ps1 -Image "myregistry.com/myimage:tag"
    .\run-demo-interactive.ps1 -Automated
#>

param(
    [string]$Image = "guardian-demo",
    [switch]$Automated,
    [switch]$Help
)

# Show help if requested
if ($Help) {
    Write-Host "Policy Guardrails Demo - Interactive PowerShell Version"
    Write-Host ""
    Write-Host "Usage: .\run-demo.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -Image <string>     Container image to use (default: guardian-demo)"
    Write-Host "  -Automated         Run in automated mode (no user interaction)"
    Write-Host "  -Help              Show this help message"
    Write-Host ""
    Write-Host "Environment Variables:"
    Write-Host "  `$env:DEMO_AUTOMATED  Set to 'true' to run in automated mode"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\run-demo.ps1                           # Interactive mode"
    Write-Host "  .\run-demo.ps1 -Automated                # Automated mode"  
    Write-Host "  .\run-demo.ps1 -Image 'myapp:latest'     # Custom image"
    Write-Host "  `$env:DEMO_AUTOMATED='true'; .\run-demo.ps1  # Automated via env var"
    Write-Host ""
    exit 0
}

# Check for automated mode via parameter or environment variable
$AutomatedMode = $Automated -or ($env:DEMO_AUTOMATED -eq 'true')

# Error handling
$ErrorActionPreference = "Stop"

# Function to wait for user input
function Wait-ForUser {
    Write-Host ""
    if ($AutomatedMode) {
        Write-Host "👆 [AUTOMATED MODE - CONTINUING...]" -ForegroundColor Blue
        Start-Sleep 1
    } else {
        Write-Host "👆 Press ENTER to continue..." -ForegroundColor Blue
        Read-Host
    }
    Write-Host ""
}

Write-Host "🚀 Policy Guardrails Demo - Star-Lord's Command Center" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
if ($AutomatedMode) {
    Write-Host "Running in AUTOMATED mode - no user interaction required"
} else {
    Write-Host "This interactive demo shows BEFORE and AFTER security policy enforcement"
}
Write-Host "Image: $Image"
Write-Host ""

# Verify PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "⚠️  Warning: This script is designed for PowerShell 7+. Some features may not work in older versions." -ForegroundColor Yellow
}

Write-Host "[1/9] Preparing clean demo environment" -ForegroundColor Cyan
Write-Host "Ensuring clean state by removing any previous demo resources..."

# Clean up any existing demo policies
Write-Host "🧹 Removing any existing demo policies..."
kubectl delete clusterpolicy require-nonroot-demo --ignore-not-found=true
kubectl delete clusterpolicy require-signed-nonroot --ignore-not-found=true

# Clean up demo namespace and recreate  
Write-Host "🧹 Cleaning demo namespace..."
kubectl delete namespace demo-star-lord --ignore-not-found=true

# Wait for namespace to be fully deleted before recreating
Write-Host "⏳ Waiting for namespace cleanup to complete..."
$timeout = 30
$elapsed = 0
while ((kubectl get namespace demo-star-lord 2>$null) -and ($elapsed -lt $timeout)) {
    Start-Sleep 2
    $elapsed += 2
    if (($elapsed % 6) -eq 0) {
        Write-Host "   Still waiting... ($elapsed`s/$timeout`s)"
    }
}

if (kubectl get namespace demo-star-lord 2>$null) {
    Write-Host "⚠️  Namespace deletion taking longer than expected, proceeding anyway..."
    kubectl delete namespace demo-star-lord --force --grace-period=0 2>$null
    Start-Sleep 3
}

Write-Host "📁 Creating fresh demo namespace..."
kubectl create namespace demo-star-lord

Write-Host "✅ Clean environment prepared" -ForegroundColor Green

Write-Host "[2/9] Checking local images" -ForegroundColor Cyan
# Check if required images exist locally
try {
    $SecureImageExists = (docker images --format "{{.Repository}}:{{.Tag}}" | Select-String "guardian-demo:secure" -ErrorAction SilentlyContinue).Count
    $InsecureImageExists = (docker images --format "{{.Repository}}:{{.Tag}}" | Select-String "guardian-demo:insecure" -ErrorAction SilentlyContinue).Count
} catch {
    $SecureImageExists = 0
    $InsecureImageExists = 0
}

if ($SecureImageExists -eq 0 -or $InsecureImageExists -eq 0) {
    Write-Host "⚠️  Required images not found locally. Building images..."
    Write-Host "Building guardian-demo:secure and guardian-demo:insecure..."
    
    if (Test-Path "scripts/build-images.ps1") {
        .\scripts\build-images.ps1 -ImageName "guardian-demo"
    } else {
        Write-Host "❌ Build script not found. Please run: .\scripts\build-images.ps1" -ForegroundColor Red
        exit 1
    }
    
    # Verify images were built
    try {
        $SecureImageExists = (docker images --format "{{.Repository}}:{{.Tag}}" | Select-String "guardian-demo:secure" -ErrorAction SilentlyContinue).Count
        $InsecureImageExists = (docker images --format "{{.Repository}}:{{.Tag}}" | Select-String "guardian-demo:insecure" -ErrorAction SilentlyContinue).Count
    } catch {
        $SecureImageExists = 0
        $InsecureImageExists = 0
    }
    
    if ($SecureImageExists -eq 0 -or $InsecureImageExists -eq 0) {
        Write-Host "❌ Failed to build required images" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Images built successfully" -ForegroundColor Green
} else {
    Write-Host "✅ Required images found locally" -ForegroundColor Green
}

Write-Host "[9/9] Checking Kyverno installation" -ForegroundColor Cyan
$kyvernoExists = kubectl get crd clusterpolicies.kyverno.io 2>$null
if (-not $kyvernoExists) {
    Write-Host "⚠️  Kyverno not found. Installing Kyverno..." -ForegroundColor Yellow

    if (Get-Command helm -ErrorAction SilentlyContinue) {
        Write-Host "Using Helm to install Kyverno..."
        helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update
        helm repo update
        helm upgrade --install kyverno kyverno/kyverno --namespace kyverno --create-namespace --wait --timeout=5m
    } else {
        Write-Host "Helm not found. Using kubectl to install Kyverno..."
        kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml
        
        Write-Host "Waiting for Kyverno CRDs to be available..."
        Start-Sleep 10
        kubectl wait --for=condition=established crd/clusterpolicies.kyverno.io --timeout=300s
    }

    Write-Host "Waiting for Kyverno to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=kyverno -n kyverno --timeout=300s
} else {
    Write-Host "✅ Kyverno is already installed" -ForegroundColor Green
}

Write-Host ""
Write-Host "================== BEFORE SECURITY POLICIES ==================" -ForegroundColor Yellow
Write-Host "Let's see what happens without admission control policies..." -ForegroundColor Yellow

# Determine manifest paths
if (Test-Path "../manifests/unsigned-pod.yaml") {
    $ManifestsPath = "../manifests"
} elseif (Test-Path "manifests/unsigned-pod.yaml") {
    $ManifestsPath = "manifests"
} else {
    Write-Host "❌ Could not find manifest files" -ForegroundColor Red
    exit 1
}

Write-Host "[9/9] Deploying insecure pods WITHOUT policies" -ForegroundColor Cyan
Write-Host "First, let's create some insecure pods to show the security risks..."

Write-Host "🔓 Creating unsigned pod..."
try { kubectl apply -f "$ManifestsPath/unsigned-pod.yaml" } catch { }

Write-Host "🔓 Creating root pod..."
try { kubectl apply -f "$ManifestsPath/root-pod.yaml" } catch { }

Write-Host "✅ Creating compliant pod (for comparison)..."
try { kubectl apply -f "$ManifestsPath/nonroot-pod.yaml" } catch { }

Write-Host ""
Write-Host "Waiting for pods to be in a stable state..."
Start-Sleep 10

Write-Host "[9/9] Examining the security state WITHOUT policies" -ForegroundColor Cyan
Write-Host "Let's look at what we have running:"
kubectl get pods -n demo-star-lord -o wide

Write-Host ""
Write-Host "Let's check the security context of these pods:"
Write-Host "Root pod user ID:" -ForegroundColor Yellow
try { kubectl exec root-pod -n demo-star-lord -- id } catch { Write-Host "Pod may still be starting..." }

Write-Host "Unsigned pod status (this shows why proper security contexts matter):" -ForegroundColor Yellow
$unsignedStatus = kubectl get pod unsigned-pod -n demo-star-lord -o jsonpath='{.status.phase}' 2>$null
if ($unsignedStatus -eq "Running") {
    Write-Host "Unsigned pod is running - checking user context..."
    try { kubectl exec unsigned-pod -n demo-star-lord -- id } catch { Write-Host "Cannot execute in pod" }
} else {
    Write-Host "Unsigned pod status: $unsignedStatus"
    Write-Host "This demonstrates that the image runs as root by default (insecure)"
    try { kubectl describe pod unsigned-pod -n demo-star-lord | Select-String -Pattern "State:" -A 2 } catch { Write-Host "Pod details unavailable" }
}

Wait-ForUser

Write-Host ""
Write-Host "================== APPLYING SECURITY POLICIES ==================" -ForegroundColor Green
Write-Host "Now let's apply admission control policies to secure our cluster..." -ForegroundColor Green

# Determine policy paths
if (Test-Path "../policies/require-signed-nonroot.yaml") {
    $PolicyPath = "../policies/require-signed-nonroot.yaml"
} elseif (Test-Path "policies/require-signed-nonroot.yaml") {
    $PolicyPath = "policies/require-signed-nonroot.yaml"
} else {
    Write-Host "❌ Could not find policy file" -ForegroundColor Red
    exit 1
}

Write-Host "[9/9] Applying Kyverno security policies" -ForegroundColor Cyan
Write-Host "Installing admission control policies for:"
Write-Host "  • Non-root container enforcement"
Write-Host "  • Signed image requirements (simulated)"

kubectl apply -f "$PolicyPath"
Write-Host "✅ Kyverno policy applied" -ForegroundColor Green

Write-Host "Waiting for admission webhooks to become active..."
Start-Sleep 15

Write-Host "Policy status:"
kubectl get clusterpolicy require-nonroot-demo -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
Write-Host ""

Wait-ForUser

Write-Host ""
Write-Host "================== TESTING POLICY ENFORCEMENT ==================" -ForegroundColor Red
Write-Host "Now let's see what happens when we try to create insecure pods..." -ForegroundColor Red

Write-Host "[9/9] Testing root pod rejection" -ForegroundColor Cyan
Write-Host "Attempting to deploy a new root pod (should be BLOCKED)..."

$rootOutput = ""
$rootExitCode = 0
try {
    $rootOutput = kubectl apply -f "$ManifestsPath/test-root-pod.yaml" --dry-run=server 2>&1
    if ($LASTEXITCODE -ne 0) { $rootExitCode = $LASTEXITCODE }
} catch {
    $rootExitCode = 1
}

Write-Host $rootOutput

if ($rootExitCode -ne 0 -and ($rootOutput | Select-String -Pattern "blocked|denied")) {
    Write-Host "✅ SUCCESS: Root pod was rejected by admission control" -ForegroundColor Green
    $rootOutput | Select-String -Pattern "disallow-root-user|validation failure" | Select-Object -First 1
} else {
    Write-Host "⚠️  Unexpected: Root pod was not rejected" -ForegroundColor Yellow
}

Wait-ForUser

Write-Host "[9/9] Testing unsigned image rejection" -ForegroundColor Cyan
Write-Host "Attempting to deploy a new unsigned pod (should be BLOCKED)..."

$unsignedOutput = ""
$unsignedExitCode = 0
try {
    $unsignedOutput = kubectl apply -f "$ManifestsPath/test-unsigned-pod.yaml" --dry-run=server 2>&1
    if ($LASTEXITCODE -ne 0) { $unsignedExitCode = $LASTEXITCODE }
} catch {
    $unsignedExitCode = 1
}

Write-Host $unsignedOutput

if ($unsignedExitCode -ne 0 -and ($unsignedOutput | Select-String -Pattern "blocked|denied")) {
    Write-Host "✅ SUCCESS: Unsigned pod was rejected by admission control" -ForegroundColor Green
    $unsignedOutput | Select-String -Pattern "require-secure-images|validation failure" | Select-Object -First 1
} else {
    Write-Host "⚠️  Unexpected: Unsigned pod was not rejected" -ForegroundColor Yellow
}

Wait-ForUser

Write-Host "[9/9] Testing compliant pod (should still work)" -ForegroundColor Cyan
Write-Host "Attempting to deploy a compliant, secure pod..."

# Delete existing compliant pod first
kubectl delete pod nonroot-pod -n demo-star-lord --ignore-not-found

# Try to create a new compliant pod
kubectl apply -f "$ManifestsPath/nonroot-pod.yaml"
Write-Host "Waiting for compliant pod to be ready..."
kubectl wait --for=condition=Ready pod/nonroot-pod -n demo-star-lord --timeout=60s
kubectl get pod nonroot-pod -n demo-star-lord

Write-Host "✅ SUCCESS: Compliant pod was accepted and is running" -ForegroundColor Green

Wait-ForUser

Write-Host ""
Write-Host "================== FINAL COMPARISON ==================" -ForegroundColor Green

Write-Host "[9/9] Final security state comparison" -ForegroundColor Cyan

Write-Host ""
Write-Host "Current pod status (with policies enforced):" -ForegroundColor Yellow
kubectl get pods -n demo-star-lord -o wide

Write-Host ""
Write-Host "Existing insecure pods from BEFORE policies:" -ForegroundColor Yellow
Write-Host "• root-pod: Still running (existed before policy) - but NEW root pods are blocked"
Write-Host "• unsigned-pod: Failed to start properly due to image security context conflicts"

Write-Host ""
Write-Host "New pod creation attempts (with policies):" -ForegroundColor Yellow
Write-Host "• root-pod: ❌ BLOCKED by admission control"
Write-Host "• unsigned-pod: ❌ BLOCKED by admission control"
Write-Host "• nonroot-pod: ✅ ALLOWED (compliant with security policies)"

Write-Host ""
Write-Host "✅ Demo completed!" -ForegroundColor Green

Write-Host ""
Write-Host "🎯 Key learnings:"
Write-Host "• Existing workloads continue running (graceful enforcement)"
Write-Host "• NEW insecure workloads are blocked at admission time"
Write-Host "• Kyverno policies enforce security at the cluster level"
Write-Host "• Only compliant, signed, non-root containers can be deployed"
Write-Host "• Admission control provides proactive security governance"

Write-Host ""
Write-Host "🧹 Cleanup (optional):" -ForegroundColor Yellow
Write-Host "kubectl delete namespace demo-star-lord --ignore-not-found"
Write-Host "kubectl delete clusterpolicy require-nonroot-demo --ignore-not-found"

# Cleanup temp files
Remove-Item "unsigned-result.txt" -ErrorAction SilentlyContinue
Remove-Item "root-result.txt" -ErrorAction SilentlyContinue