#requires -Version 7.0
<#
.SYNOPSIS
    Observability Signals Demo - Cleanup Script
    Removes demo namespace and Falcosidekick

.DESCRIPTION
    Cleans up the Observability Signals demo by removing:
    - demo-mantis namespace (includes OTEL collector and instrumented API)
    - Falcosidekick installation
    - Demo telemetry image (optional)

    Falco installation is preserved. The shared kind cluster and registry
    container are owned by teardown-kind-cluster.{sh,ps1} and are NOT touched.

.PARAMETER Namespace
    The demo namespace to remove. Defaults to "demo-mantis".

.EXAMPLE
    .\cleanup.ps1

.EXAMPLE
    .\cleanup.ps1 -Namespace demo-mantis
#>

param(
    [string]$Namespace = "demo-mantis"
)

$ErrorActionPreference = 'Stop'

Write-Host "🧹 Observability Signals Demo - Cleanup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Removing demo namespace and Falcosidekick"
Write-Host ""

Write-Host "[1/3] Removing demo namespace" -ForegroundColor Cyan
kubectl delete namespace $Namespace --ignore-not-found
Write-Host "✅ Demo namespace removed (includes OTEL collector and instrumented API)"

Write-Host "[2/3] Uninstalling Falcosidekick" -ForegroundColor Cyan
if (Get-Command helm -ErrorAction SilentlyContinue) {
    Write-Host "Using Helm to uninstall Falcosidekick..."
    helm uninstall falcosidekick -n falco --ignore-not-found 2>$null
} else {
    Write-Host "Helm not found. Skipping Falcosidekick removal..."
}
Write-Host "✅ Falcosidekick removed"

Write-Host "[3/3] Removing demo image (optional)" -ForegroundColor Cyan
docker rmi guardian-telemetry:local 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Image not found locally (skipping)"
}
Write-Host "✅ Cleanup completed"

Write-Host ""
Write-Host "✅ Cleanup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Removed resources:"
Write-Host "• $Namespace namespace"
Write-Host "• OTEL collector deployment"
Write-Host "• Instrumented API and load generator"
Write-Host "• Falcosidekick installation"
Write-Host ""
Write-Host "Note: " -ForegroundColor Yellow -NoNewline
Write-Host "Falco installation is preserved. To remove, run cleanup from demo 4"
