#requires -Version 7.0
# Zero Trust Networking Demo - Cleanup Script
# Removes demo namespace and network policies
$ErrorActionPreference = 'Stop'

Write-Host "Zero Trust Networking Demo - Cleanup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Removing demo namespace and network policies"
Write-Host ""

Write-Host "[1/1] Removing demo namespace" -ForegroundColor Cyan
kubectl delete namespace demo-groot --ignore-not-found
Write-Host "Demo namespace removed (includes all pods, services, and network policies)"

Write-Host ""
Write-Host "Cleanup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Removed resources:"
Write-Host "- demo-groot namespace"
Write-Host "- frontend, api, and db deployments"
Write-Host "- tester pod"
Write-Host "- All NetworkPolicies (default-deny and allow policies)"
