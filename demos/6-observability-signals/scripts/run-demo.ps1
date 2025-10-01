#requires -Version 7.0
param(
    [string]$Namespace = "demo-mantis",
    [string]$Image = "ghcr.io/codebytes/guardian-telemetry:0.1.0",
    [switch]$BuildImage
)

$ErrorActionPreference = 'Stop'

if ($BuildImage) {
    Write-Host "[0/9] Building telemetry image $Image" -ForegroundColor Cyan
    push-location ..\app
    docker build -t $Image .
    pop-location
}

Write-Host "[1/9] Creating namespace" -ForegroundColor Cyan
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - | Out-Null

Write-Host "[2/9] Applying OpenTelemetry collector" -ForegroundColor Cyan
kubectl apply -f ..\collector\otel-collector.yaml --namespace $Namespace | Out-Null
kubectl rollout status deployment/otel-collector -n $Namespace

Write-Host "[3/9] Installing Falcosidekick (if Falco already installed)" -ForegroundColor Cyan
helm repo add falcosecurity https://falcosecurity.github.io/charts | Out-Null
helm repo update | Out-Null
helm upgrade --install falcosidekick falcosecurity/falcosidekick `
  --namespace falco `
  --create-namespace `
  -f ..\manifests\falcosidekick-config.yaml | Out-Null

Write-Host "[4/9] Deploying instrumented API" -ForegroundColor Cyan
kubectl set image -n $Namespace -f ..\manifests\instrumented-api.yaml app=$Image --local -o yaml | kubectl apply -n $Namespace -f - | Out-Null
kubectl rollout status deployment/guardian-telemetry -n $Namespace

Write-Host "[5/9] Deploying load generator" -ForegroundColor Cyan
kubectl apply -f ..\manifests\load-generator.yaml -n $Namespace | Out-Null
kubectl wait --for=condition=complete job/telemetry-load -n $Namespace --timeout=120s | Out-Null

Write-Host "[6/9] Tailing OTEL collector logs for spans" -ForegroundColor Cyan
kubectl logs deployment/otel-collector -n $Namespace --tail=20 | Select-String "guardian"

Write-Host "[7/9] Optional: Trigger Falco rule (see runtime demo)" -ForegroundColor Yellow
Write-Host "          Run scripts/run-demo.ps1 from runtime-detection to generate alert" -ForegroundColor Yellow

Write-Host "[8/9] Port-forward Prometheus endpoint" -ForegroundColor Cyan
Write-Host "kubectl port-forward svc/otel-collector -n $Namespace 9464:9464" -ForegroundColor DarkGray

Write-Host "[9/9] Cleanup reminder" -ForegroundColor Cyan
Write-Host "kubectl delete namespace $Namespace" -ForegroundColor DarkGray
