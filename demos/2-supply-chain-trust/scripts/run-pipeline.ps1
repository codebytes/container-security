#requires -Version 7.0
param(
    [string]$Registry = "localhost:5000",
    [string]$ImageName = "guardian-demo-app", 
    [string]$Tag = "v0.1.0-secure"
)

$ErrorActionPreference = 'Stop'
$workingRoot = (Resolve-Path "..").Path
$fullImage = "${Registry}/${ImageName}:${Tag}"

Write-Host "[1/6] Building image $fullImage" -ForegroundColor Cyan
set-location ../
docker build -f pipeline/Dockerfile -t $fullImage .

Write-Host "[2/6] Generating SBOM" -ForegroundColor Cyan
syft packages $fullImage -o json > attestations/sbom.json

Write-Host "[3/6] Scanning with Trivy" -ForegroundColor Cyan
trivy image --severity HIGH,CRITICAL --exit-code 1 $fullImage

Write-Host "[4/6] Pushing image" -ForegroundColor Cyan
docker push $fullImage

Write-Host "[5/6] Signing image" -ForegroundColor Cyan
cosign sign $fullImage

Write-Host "[6/6] Verifying signature" -ForegroundColor Cyan
cosign verify $fullImage

Write-Host "Pipeline completed" -ForegroundColor Green
set-location $workingRoot