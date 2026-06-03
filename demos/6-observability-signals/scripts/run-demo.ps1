#requires -Version 7.0
param(
    [string]$Namespace = "demo-mantis",
    [string]$Image = "guardian-telemetry:local"
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$DemoDir = Split-Path -Parent $ScriptDir
$DemosDir = Split-Path -Parent $DemoDir
$RuntimeDemoDir = Join-Path $DemosDir '4-runtime-detection'
$RuntimeDemoScript = Join-Path $RuntimeDemoDir 'scripts\run-demo.ps1'
$CleanupScript = Join-Path $ScriptDir 'cleanup.ps1'
$AppDir = Join-Path $DemoDir 'app'
$CollectorManifest = Join-Path $DemoDir 'collector\otel-collector.yaml'
$ManifestsDir = Join-Path $DemoDir 'manifests'
$FalcoOtlpAdapterManifest = Join-Path $ManifestsDir 'falco-otlp-adapter.yaml'
$FalcosidekickConfig = Join-Path $ManifestsDir 'falcosidekick-config.yaml'
$InstrumentedApiManifest = Join-Path $ManifestsDir 'instrumented-api.yaml'
$LoadGeneratorManifest = Join-Path $ManifestsDir 'load-generator.yaml'

function Test-RequiredTools {
    $missing = @()
    foreach ($tool in @('docker', 'kubectl', 'helm')) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            $missing += $tool
        }
    }

    if ($missing.Count -gt 0) {
        Write-Host "ERROR: missing prerequisite(s): $($missing -join ', ')" -ForegroundColor Red
        if ($missing -contains 'helm') {
            Write-Host "Install Helm before running this demo:" -ForegroundColor Yellow
            Write-Host "  Windows: winget install Helm.Helm"
            Write-Host "  macOS:   brew install helm"
        }
        Write-Host "Install the missing tool(s), then re-run this script." -ForegroundColor Yellow
        exit 1
    }
}

function Test-FalcoHandoff {
    $falcoNamespace = kubectl get namespace falco --ignore-not-found -o name 2>$null
    $falcoDaemonSet = kubectl get daemonset falco -n falco --ignore-not-found -o name 2>$null
    helm status falco -n falco >$null 2>$null
    $falcoHelmReleaseFound = ($LASTEXITCODE -eq 0)

    if (-not $falcoNamespace -or -not $falcoDaemonSet -or -not $falcoHelmReleaseFound) {
        Write-Host "ERROR: Falco is not deployed for the demo 6 handoff." -ForegroundColor Red
        Write-Host "Demo 6 expects demo 4 (demos\4-runtime-detection) to install the falco namespace, Helm release, and DaemonSet first." -ForegroundColor Yellow
        Write-Host "Run demo 4 first, then re-run this script:" -ForegroundColor Yellow
        Write-Host "  Set-Location -Path '$RuntimeDemoDir'"
        Write-Host "  .\scripts\run-demo.ps1"
        exit 1
    }
}

Test-RequiredTools
Test-FalcoHandoff

Write-Host "[1/9] Building telemetry image $Image" -ForegroundColor Cyan
Push-Location $AppDir
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
kubectl apply -f $CollectorManifest --namespace $Namespace | Out-Null
kubectl rollout status deployment/otel-collector -n $Namespace

Write-Host "[4/9] Installing Falcosidekick" -ForegroundColor Cyan
Write-Host "       Deploying Falco->OTLP adapter" -ForegroundColor DarkGray
kubectl apply -f $FalcoOtlpAdapterManifest -n $Namespace | Out-Null
kubectl rollout status deployment/falco-otlp-adapter -n $Namespace
helm repo add falcosecurity https://falcosecurity.github.io/charts | Out-Null
helm repo update | Out-Null
helm upgrade --install falcosidekick falcosecurity/falcosidekick `
  --namespace falco `
  --create-namespace `
  -f $FalcosidekickConfig `
  --wait | Out-Null
Write-Host "       Configuring Falco HTTP output to send alerts to Falcosidekick" -ForegroundColor DarkGray
helm upgrade falco falcosecurity/falco `
  --namespace falco `
  --reuse-values `
  --set falco.json_output=true `
  --set falco.http_output.enabled=true `
  --set falco.http_output.url=http://falcosidekick.falco.svc.cluster.local:2801/ `
  --wait | Out-Null

Write-Host "[5/9] Deploying instrumented API" -ForegroundColor Cyan
kubectl apply -f $InstrumentedApiManifest -n $Namespace | Out-Null
kubectl wait --for=condition=available --timeout=120s deployment/guardian-telemetry -n $Namespace

Write-Host "[6/9] Deploying load generator" -ForegroundColor Cyan
kubectl apply -f $LoadGeneratorManifest -n $Namespace | Out-Null
kubectl wait --for=condition=complete job/telemetry-load -n $Namespace --timeout=120s | Out-Null

Write-Host "[7/9] Tailing OTEL collector logs for spans" -ForegroundColor Cyan
kubectl logs deployment/otel-collector -n $Namespace --tail=100 | Select-String "ResourceSpans|Span #|guardian-telemetry|ScopeSpans"

Write-Host "[8/9] Optional: Trigger Falco rule (see runtime demo)" -ForegroundColor Yellow
Write-Host "          Run $RuntimeDemoScript to generate alert" -ForegroundColor Yellow

Write-Host "[9/9] Port-forward Prometheus endpoint / cleanup" -ForegroundColor Cyan
Write-Host "kubectl port-forward svc/otel-collector -n $Namespace 9464:9464" -ForegroundColor DarkGray
Write-Host $CleanupScript -ForegroundColor DarkGray
