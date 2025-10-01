#requires -Version 7.0
<#
.SYNOPSIS
    Policy Guardrails Demo - Cleanup Script
    Removes all demo resources including Kyverno installation

.DESCRIPTION
    This script completely cleans up the Policy Guardrails demo by removing:
    - demo-star-lord namespace
    - Kyverno policies
    - Kyverno installation
    - Temporary files

.EXAMPLE
    .\cleanup.ps1
#>

# Error handling
$ErrorActionPreference = "Continue"

Write-Host "🧹 Policy Guardrails Demo - Cleanup" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Removing all demo resources and Kyverno installation"
Write-Host ""

Write-Host "[1/4] Removing demo namespace" -ForegroundColor Cyan
kubectl delete namespace demo-star-lord --ignore-not-found
Write-Host "✅ Demo namespace removed" -ForegroundColor Green

Write-Host "[2/4] Removing Kyverno policies" -ForegroundColor Cyan
kubectl delete clusterpolicy require-nonroot-demo --ignore-not-found
Write-Host "✅ Kyverno policies removed" -ForegroundColor Green

Write-Host "[3/4] Uninstalling Kyverno" -ForegroundColor Cyan
if (Get-Command helm -ErrorAction SilentlyContinue) {
    Write-Host "Using Helm to uninstall Kyverno..."
    helm uninstall kyverno -n kyverno --ignore-not-found 2>$null
} else {
    Write-Host "Helm not found. Removing Kyverno manually..."
    kubectl delete namespace kyverno --ignore-not-found 2>$null
}

# Clean up any remaining Kyverno resources
Write-Host "Cleaning up remaining Kyverno resources..."

# Clean up CRDs
$kyvernoCRDs = kubectl get crd 2>$null | Select-String "kyverno" | ForEach-Object { ($_ -split '\s+')[0] }
if ($kyvernoCRDs) {
    $kyvernoCRDs | ForEach-Object { kubectl delete crd $_ --ignore-not-found 2>$null }
}

$policyCRDs = kubectl get crd 2>$null | Select-String "wgpolicyk8s" | ForEach-Object { ($_ -split '\s+')[0] }
if ($policyCRDs) {
    $policyCRDs | ForEach-Object { kubectl delete crd $_ --ignore-not-found 2>$null }
}

# Clean up RBAC
$kyvernoRoles = kubectl get clusterrole 2>$null | Select-String "kyverno" | ForEach-Object { ($_ -split '\s+')[0] }
if ($kyvernoRoles) {
    $kyvernoRoles | ForEach-Object { kubectl delete clusterrole $_ --ignore-not-found 2>$null }
}

$kyvernoBindings = kubectl get clusterrolebinding 2>$null | Select-String "kyverno" | ForEach-Object { ($_ -split '\s+')[0] }
if ($kyvernoBindings) {
    $kyvernoBindings | ForEach-Object { kubectl delete clusterrolebinding $_ --ignore-not-found 2>$null }
}

Write-Host "✅ Kyverno completely removed" -ForegroundColor Green

Write-Host "[4/4] Cleaning up temporary files" -ForegroundColor Cyan
Remove-Item -Path "/tmp/unsigned-result.txt", "/tmp/root-result.txt", "/tmp/test-root-pod.yaml" -ErrorAction SilentlyContinue
Remove-Item -Path "unsigned-result.txt", "root-result.txt" -ErrorAction SilentlyContinue
Write-Host "✅ Temporary files cleaned" -ForegroundColor Green

Write-Host ""
Write-Host "✅ Cleanup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Removed resources:"
Write-Host "• demo-star-lord namespace"
Write-Host "• require-nonroot-demo ClusterPolicy"
Write-Host "• Kyverno admission controller"
Write-Host "• All Kyverno CRDs and RBAC resources"
Write-Host "• Temporary files"
Write-Host ""
Write-Host "Note: Docker images (guardian-demo:secure, guardian-demo:insecure) are preserved for reuse" -ForegroundColor Yellow