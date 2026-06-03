#requires -Version 7.0
# Runtime Detection Demo - Cleanup Script
# Removes Falco and demo resources
$ErrorActionPreference = 'Stop'

Write-Host "🧹 Runtime Detection Demo - Cleanup" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Removing Falco and demo resources"
Write-Host ""

Write-Host "[1/4] Removing demo namespace" -ForegroundColor Cyan
kubectl delete namespace demo-drax --ignore-not-found
Write-Host "✅ Demo namespace removed"

Write-Host "[2/4] Removing trigger pod" -ForegroundColor Cyan
try {
    kubectl delete -f ../manifests/trigger-pod.yaml --ignore-not-found 2>$null
} catch {
    # Ignore errors if the manifest or resource is already gone
}
Write-Host "✅ Trigger pod removed"

Write-Host "[3/4] Custom rules" -ForegroundColor Cyan
Write-Host "✅ Custom rule is delivered via Helm customRules; removed with the Falco release below"

Write-Host "[4/4] Uninstalling Falco" -ForegroundColor Cyan
if (Get-Command helm -ErrorAction SilentlyContinue) {
    Write-Host "Using Helm to uninstall Falco..."
    $falcoRelease = helm list -n falco 2>$null | Select-String -Pattern 'falco'
    if ($falcoRelease) {
        helm uninstall falco -n falco
        Write-Host "✅ Falco Helm release uninstalled"
    } else {
        Write-Host "No Falco Helm release found"
    }
} else {
    Write-Host "Helm not found. Removing Falco manually..."
}

Write-Host "Removing Falco namespace" -ForegroundColor Cyan
kubectl delete namespace falco --ignore-not-found 2>$null | Out-Null
Write-Host "✅ Falco namespace removed"

Write-Host ""
Write-Host "✅ Cleanup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Removed resources:"
Write-Host "• demo-drax namespace"
Write-Host "• Trigger pod"
Write-Host "• Custom Falco rules"
Write-Host "• Falco installation"
Write-Host "• Falco namespace"
Write-Host ""
Write-Host "Note:" -ForegroundColor Yellow -NoNewline
Write-Host " To keep Falco for exploration, comment out the uninstall step in the script"
