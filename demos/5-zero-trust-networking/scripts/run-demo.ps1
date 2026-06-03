#requires -Version 7.0
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$DemoDir = Split-Path -Parent $ScriptDir
$ManifestsDir = Join-Path $DemoDir 'manifests'

Write-Host "[1/8] Creating namespace" -ForegroundColor Cyan
kubectl create namespace demo-groot --dry-run=client -o yaml | kubectl apply -f - | Out-Null

Write-Host "[2/8] Deploying services" -ForegroundColor Cyan
kubectl apply -f (Join-Path $ManifestsDir 'base-services.yaml') | Out-Null
kubectl rollout status deployment/frontend -n demo-groot
kubectl rollout status deployment/api -n demo-groot
kubectl rollout status deployment/db -n demo-groot

Write-Host "[3/8] Applying default deny policies" -ForegroundColor Cyan
kubectl apply -f (Join-Path $ManifestsDir 'default-deny.yaml') | Out-Null

Write-Host "[4/8] Applying allow policies" -ForegroundColor Cyan
kubectl apply -f (Join-Path $ManifestsDir 'allow-policies.yaml') | Out-Null

Write-Host "[5/8] Launching tester pod" -ForegroundColor Cyan
kubectl apply -f (Join-Path $ManifestsDir 'tester-pod.yaml') | Out-Null
kubectl wait --for=condition=Ready pod/tester -n demo-groot --timeout=60s

Write-Host "[6/8] Testing blocked and allowed traffic" -ForegroundColor Cyan

Write-Host "Test 1: tester -> api (should be blocked)" -ForegroundColor Cyan
kubectl exec -n demo-groot tester -- curl -sS --connect-timeout 3 api:8080/get
if ($LASTEXITCODE -eq 0) {
    Write-Host "Unexpected success: tester reached api; NetworkPolicies may not be enforced" -ForegroundColor Red
} else {
    Write-Host "Expected failure: tester blocked from api" -ForegroundColor Yellow
}

Write-Host "Test 2: tester -> db (should be blocked)" -ForegroundColor Cyan
kubectl run tester-db-probe -n demo-groot --rm -i --restart=Never --labels=app=tester --image=postgres:16-alpine --command -- pg_isready -h db -p 5432 -U postgres -t 3
if ($LASTEXITCODE -eq 0) {
    Write-Host "Unexpected success: tester-labeled probe reached db; NetworkPolicies may not be enforced" -ForegroundColor Red
} else {
    Write-Host "Expected failure: tester-labeled probe blocked from db" -ForegroundColor Yellow
}

Write-Host "Test 3: frontend -> api (should work)" -ForegroundColor Cyan
$frontendOutput = kubectl run frontend-probe -n demo-groot --rm -i --restart=Never --labels=app=frontend --image=curlimages/curl:8.8.0 --command -- curl -sS --connect-timeout 3 api:8080/get 2>&1
if ($LASTEXITCODE -eq 0 -and ($frontendOutput -join "`n") -match '"url"') {
    Write-Host "Success: frontend-labeled probe reached api" -ForegroundColor Green
} else {
    Write-Host "Failure: frontend-labeled probe could not reach api" -ForegroundColor Red
    Write-Host ($frontendOutput -join "`n") -ForegroundColor Yellow
}

Write-Host "Test 4: api -> db (should work)" -ForegroundColor Cyan
$apiDbOutput = kubectl run api-db-probe -n demo-groot --rm -i --restart=Never --labels=app=api --image=postgres:16-alpine --command -- pg_isready -h db -p 5432 -U postgres -t 3 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Success: api-labeled probe reached db" -ForegroundColor Green
} else {
    Write-Host "Failure: api-labeled probe could not reach db" -ForegroundColor Red
    Write-Host ($apiDbOutput -join "`n") -ForegroundColor Yellow
}

Write-Host "[7/8] Temporarily allowing tester to api" -ForegroundColor Cyan
kubectl apply -f (Join-Path $ManifestsDir 'allow-tester-api.yaml') | Out-Null
Start-Sleep -Seconds 3
kubectl exec -n demo-groot tester -- curl -sS --connect-timeout 3 api:8080/get
if ($LASTEXITCODE -eq 0) {
    Write-Host "Success: tester can now reach api" -ForegroundColor Green
} else {
    Write-Host "Failure: tester is still blocked from api" -ForegroundColor Red
}

Write-Host "[8/8] Cleanup" -ForegroundColor Cyan
kubectl delete -f (Join-Path $ManifestsDir 'allow-tester-api.yaml') --ignore-not-found | Out-Null
kubectl delete namespace demo-groot --ignore-not-found | Out-Null

Write-Host "Demo complete" -ForegroundColor Green
