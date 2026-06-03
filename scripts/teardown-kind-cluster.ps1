#requires -Version 7.0
<#
.SYNOPSIS
    Tear down the shared container-security demo cluster (PowerShell twin of
    teardown-kind-cluster.sh).

.DESCRIPTION
    Counterpart to scripts/setup-kind-cluster.ps1. Because the kind nodes are
    containers, deleting the cluster removes ALL demo workloads and namespaces in
    one shot — individual demos do NOT need their own teardown.

    Also removes the shared local registry (registry:2 on host port 5000) that
    setup wired into the `kind` docker network, and cleans up the `kind` network
    if nothing else is using it.

    Safe to run repeatedly: no errors if the cluster/registry are already gone.

.PARAMETER Force
    Skip the confirmation prompt (CI-friendly).
#>
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$ClusterName = "container-security"
$KindNetwork = "kind"
$RegName     = "registry"

Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Teardown kind Cluster + Registry         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will remove:"
Write-Host "  • kind cluster '$ClusterName' (and all demo workloads/namespaces)"
Write-Host "  • local registry container '$RegName'"
Write-Host "  • the '$KindNetwork' docker network (only if unused)"
Write-Host ""

if (-not $Force) {
    $response = Read-Host "Proceed with teardown? (y/N)"
    if ($response -notmatch '^[Yy]$') {
        Write-Host "Aborted."
        exit 0
    }
}

# ── Step 1: Delete the kind cluster (idempotent) ────────────────────────────
Write-Host ""
Write-Host "[1/3] Deleting kind cluster '$ClusterName'..." -ForegroundColor Cyan
$kindAvailable = Get-Command kind -ErrorAction SilentlyContinue
$clusterExists = $false
if ($kindAvailable) {
    $clusterExists = (kind get clusters 2>$null) | Select-String -Pattern "^$ClusterName$"
}
if ($clusterExists) {
    kind delete cluster --name $ClusterName
    Write-Host "✅ Cluster deleted" -ForegroundColor Green
} else {
    Write-Host "✅ Cluster '$ClusterName' not present (nothing to delete)" -ForegroundColor Green
}
Write-Host ""

# ── Step 2: Stop and remove the shared registry (idempotent) ────────────────
Write-Host "[2/3] Removing local registry container '$RegName'..." -ForegroundColor Cyan
$regExists = docker ps -aq -f "name=^$RegName$" 2>$null
if ($regExists) {
    docker rm -f $RegName 2>$null | Out-Null
    Write-Host "✅ Registry container removed" -ForegroundColor Green
} else {
    Write-Host "✅ Registry container not present (nothing to remove)" -ForegroundColor Green
}
Write-Host ""

# ── Step 3: Clean up the kind docker network if unused ──────────────────────
Write-Host "[3/3] Cleaning up the '$KindNetwork' docker network (if unused)..." -ForegroundColor Cyan
$netExists = docker network inspect $KindNetwork 2>$null
if ($netExists) {
    $attached = docker network inspect $KindNetwork -f '{{len .Containers}}' 2>$null
    if ($attached -eq '0') {
        try {
            docker network rm $KindNetwork 2>$null | Out-Null
            Write-Host "✅ Network '$KindNetwork' removed" -ForegroundColor Green
        } catch {
            Write-Host "ℹ️  Network '$KindNetwork' could not be removed (may be managed by kind)"
        }
    } else {
        Write-Host "ℹ️  Network '$KindNetwork' still has $attached attached container(s); leaving it in place"
    }
} else {
    Write-Host "✅ Network '$KindNetwork' not present (nothing to clean up)" -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ Teardown complete." -ForegroundColor Green
Write-Host ""
Write-Host "To recreate the cluster:"
Write-Host "  ./scripts/setup-kind-cluster.ps1"
