#requires -Version 7.0
$ErrorActionPreference = 'Stop'

Write-Host "[1/7] Ensuring namespaces" -ForegroundColor Cyan
kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f - | Out-Null
kubectl create namespace demo-drax --dry-run=client -o yaml | kubectl apply -f - | Out-Null

Write-Host "[2/7] Installing Falco via Helm" -ForegroundColor Cyan
helm repo add falcosecurity https://falcosecurity.github.io/charts | Out-Null
helm repo update | Out-Null
helm upgrade --install falco falcosecurity/falco `
  --namespace falco `
  --set driver.kind=ebpf | Out-Null

Write-Host "[3/7] Applying custom rule ConfigMap" -ForegroundColor Cyan
kubectl apply -f ../manifests/falco-rules-configmap.yaml | Out-Null

Write-Host "[4/7] Patching daemonset to mount custom rules" -ForegroundColor Cyan
kubectl patch daemonset falco -n falco --type merge --patch-file ../manifests/falco-daemonset-patch.yaml | Out-Null
kubectl rollout status daemonset falco -n falco

Write-Host "[5/7] Deploying trigger pod" -ForegroundColor Cyan
kubectl apply -f ../manifests/trigger-pod.yaml | Out-Null
Start-Sleep -Seconds 5

Write-Host "[6/7] Tailing Falco logs" -ForegroundColor Cyan
kubectl logs -n falco daemonset/falco --since=2m | Select-String "Write Below Etc Demo"

Write-Host "[7/7] Cleanup" -ForegroundColor Cyan
kubectl delete -f ../manifests/trigger-pod.yaml --ignore-not-found | Out-Null
# Optional: comment out next two lines to keep Falco installed for exploration
# kubectl delete -f ../manifests/falco-rules-configmap.yaml --ignore-not-found | Out-Null
# helm uninstall falco -n falco | Out-Null

Write-Host "Demo complete" -ForegroundColor Green
