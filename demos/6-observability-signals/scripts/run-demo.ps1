#requires -Version 7.0
param(
    [string]$Namespace = "demo-mantis",
    [string]$Image = "guardian-telemetry:local"
)

$ErrorActionPreference = 'Stop'

Write-Host "[1/9] Building telemetry image $Image" -ForegroundColor Cyan
Push-Location ..\app
docker build -t $Image .
Pop-Location
Write-Host "Image built"

# Load the locally built image into the kind node when on a kind context,
# matching run-demo.sh (imagePullPolicy: Never requires it to be preloaded).
$currentContext = (kubectl config current-context)
if ($currentContext -like 'kind-*') {
    $clusterName = $currentContext.Substring('kind-'.Length)
    Write-Host "Detected kind cluster: $clusterName - loading image" -ForegroundColor Cyan
    if (Get-Command kind -ErrorAction SilentlyContinue) {
        kind load docker-image $Image --name $clusterName
        Write-Host "Image loaded into kind"
    } else {
        Write-Host "kind command not found. Manually load with:" -ForegroundColor Yellow
        Write-Host "   kind load docker-image $Image --name $clusterName"
    }
}

Write-Host "[2/9] Creating namespace" -ForegroundColor Cyan
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - | Out-Null

Write-Host "[3/9] Applying OpenTelemetry collector" -ForegroundColor Cyan
kubectl apply -f ..\collector\otel-collector.yaml --namespace $Namespace | Out-Null
kubectl rollout status deployment/otel-collector -n $Namespace

Write-Host "[4/9] Installing Falcosidekick (if Falco already installed)" -ForegroundColor Cyan
Write-Host "       Deploying Falco->OTLP adapter" -ForegroundColor DarkGray
kubectl apply -f ..\manifests\falco-otlp-adapter.yaml -n $Namespace | Out-Null
kubectl rollout status deployment/falco-otlp-adapter -n $Namespace
helm repo add falcosecurity https://falcosecurity.github.io/charts | Out-Null
helm repo update | Out-Null
helm upgrade --install falcosidekick falcosecurity/falcosidekick `
  --namespace falco `
  --create-namespace `
  -f ..\manifests\falcosidekick-config.yaml | Out-Null

Write-Host "[5/9] Deploying instrumented API" -ForegroundColor Cyan
kubectl apply -f ..\manifests\instrumented-api.yaml -n $Namespace | Out-Null
kubectl wait --for=condition=available --timeout=120s deployment/guardian-telemetry -n $Namespace

Write-Host "[6/9] Deploying load generator" -ForegroundColor Cyan
kubectl apply -f ..\manifests\load-generator.yaml -n $Namespace | Out-Null
kubectl wait --for=condition=complete job/telemetry-load -n $Namespace --timeout=120s | Out-Null

Write-Host "[7/9] Tailing OTEL collector logs for spans" -ForegroundColor Cyan
kubectl logs deployment/otel-collector -n $Namespace --tail=100 | Select-String "ResourceSpans|Span #|guardian-telemetry|ScopeSpans"

Write-Host "[8/9] Optional: Trigger Falco rule (see runtime demo)" -ForegroundColor Yellow
Write-Host "          Run scripts/run-demo.ps1 from runtime-detection to generate alert" -ForegroundColor Yellow

Write-Host "[9/9] Port-forward Prometheus endpoint / cleanup" -ForegroundColor Cyan
Write-Host "kubectl port-forward svc/otel-collector -n $Namespace 9464:9464" -ForegroundColor DarkGray
Write-Host ".\cleanup.ps1" -ForegroundColor DarkGray
