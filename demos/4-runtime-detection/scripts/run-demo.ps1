#requires -Version 7.0
$ErrorActionPreference = 'Stop'

Write-Host "[1/6] Ensuring namespaces" -ForegroundColor Cyan
kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f - | Out-Null
kubectl create namespace demo-drax --dry-run=client -o yaml | kubectl apply -f - | Out-Null

Write-Host "[2/6] Installing Falco with custom rule via Helm customRules" -ForegroundColor Cyan
helm repo add falcosecurity https://falcosecurity.github.io/charts | Out-Null
helm repo update | Out-Null
helm upgrade --install falco falcosecurity/falco `
  --namespace falco `
  --values ../manifests/falco-values.yaml `
  --wait | Out-Null

Write-Host "[3/6] Waiting for Falco to be ready" -ForegroundColor Cyan
kubectl rollout status daemonset/falco -n falco

Write-Host "[4/6] Deploying trigger pod" -ForegroundColor Cyan
kubectl apply -f ../manifests/trigger-pod.yaml | Out-Null
Start-Sleep -Seconds 8

Write-Host "[5/6] Tailing Falco logs" -ForegroundColor Cyan
kubectl logs -n falco daemonset/falco -c falco --since=2m | Select-String "Write below /etc detected"

Write-Host "[6/6] Cleanup" -ForegroundColor Cyan
kubectl delete -f ../manifests/trigger-pod.yaml --ignore-not-found | Out-Null
# Optional: uncomment to fully tear down Falco after the demo
# helm uninstall falco -n falco | Out-Null

Write-Host "Demo complete" -ForegroundColor Green
