#requires -Version 7.0
<#
.SYNOPSIS
    Image Hardening Demo - Cleanup Script
    Removes demo images and reports

.DESCRIPTION
    Removes the demo-3 (image hardening) resources:
    - guardian-demo:before image
    - guardian-demo:after image
    - Vulnerability scan reports (../reports/*.txt)

    Scoped to demo-3-specific resources. Does NOT touch the shared kind
    cluster or the shared "registry" container (owned by
    teardown-kind-cluster.{sh,ps1}). Idempotent: does not error if
    resources are already gone.

.EXAMPLE
    .\cleanup.ps1
#>

$ErrorActionPreference = 'Stop'

Write-Host "🧹 Image Hardening Demo - Cleanup" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Removing demo images and reports"
Write-Host ""

Write-Host "[1/2] Removing demo images" -ForegroundColor Cyan
docker rmi guardian-demo:before 2>$null | Out-Null
docker rmi guardian-demo:after 2>$null | Out-Null
Write-Host "✅ Demo images removed"

Write-Host "[2/2] Removing vulnerability reports" -ForegroundColor Cyan
$reportsDir = Join-Path $PSScriptRoot "../reports"
if (Test-Path $reportsDir) {
    Remove-Item -Path (Join-Path $reportsDir "*.txt") -Force -ErrorAction SilentlyContinue
}
Write-Host "✅ Reports cleaned"

Write-Host ""
Write-Host "✅ Cleanup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Removed resources:"
Write-Host "• guardian-demo:before image"
Write-Host "• guardian-demo:after image"
Write-Host "• Vulnerability scan reports"
