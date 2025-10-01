#requires -Version 7.0
$ErrorActionPreference = 'Stop'

Write-Host "[1/8] Creating namespace" -ForegroundColor Cyan
kubectl create namespace demo-groot --dry-run=client -o yaml | kubectl apply -f - | Out-Null

Write-Host "[2/8] Deploying services" -ForegroundColor Cyan
kubectl apply -f ../manifests/base-services.yaml | Out-Null
kubectl rollout status deployment/frontend -n demo-groot
kubectl rollout status deployment/api -n demo-groot
kubectl rollout status deployment/db -n demo-groot

Write-Host "[3/8] Applying default deny policies" -ForegroundColor Cyan
kubectl apply -f ../manifests/default-deny.yaml | Out-Null

Write-Host "[4/8] Applying allow policies" -ForegroundColor Cyan
kubectl apply -f ../manifests/allow-policies.yaml | Out-Null

Write-Host "[5/8] Launching tester pod" -ForegroundColor Cyan
kubectl apply -f ../manifests/tester-pod.yaml | Out-Null
kubectl wait --for=condition=Ready pod/tester -n demo-groot --timeout=60s

Write-Host "[6/8] Testing blocked traffic" -ForegroundColor Cyan
kubectl exec -n demo-groot tester -- curl -sS api:8080/health || Write-Host "Expected failure: tester blocked from api" -ForegroundColor Yellow
kubectl exec -n demo-groot tester -- curl -sS db:5432 || Write-Host "Expected failure: tester blocked from db" -ForegroundColor Yellow

Write-Host "[7/8] Temporarily allowing tester to api" -ForegroundColor Cyan
kubectl apply -f ../manifests/allow-tester-api.yaml | Out-Null
Start-Sleep -Seconds 3
kubectl exec -n demo-groot tester -- curl -sS api:8080/health

Write-Host "[8/8] Cleanup" -ForegroundColor Cyan
kubectl delete -f ../manifests/allow-tester-api.yaml --ignore-not-found | Out-Null
kubectl delete namespace demo-groot --ignore-not-found | Out-Null

Write-Host "Demo complete" -ForegroundColor Green
