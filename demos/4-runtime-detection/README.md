# Runtime Detection Demo (Drax)

## Purpose
Show how Falco detects suspicious container activity (writing below `/etc`) and how alerts can be captured for incident response.

## Outcomes
- Deploy Falco to a Kubernetes cluster (Helm quickstart).
- Apply a custom Falco rule tailored to demo behavior.
- Trigger the rule using a controlled pod that writes to `/etc/shadow`.
- Observe alert output via `kubectl logs` or Falcosidekick webhook.

## Prerequisites
- Kubernetes cluster with `kubectl` access.
- Helm 3.
- Optional: Falcosidekick for forwarding alerts to Slack/Webhook (not required here).

## Environment Preparation
1. **Install Falco**
   ```powershell
   helm repo add falcosecurity https://falcosecurity.github.io/charts
   helm repo update
   helm upgrade --install falco falcosecurity/falco \
     --namespace falco --create-namespace \
     --set driver.kind=ebpf
   ```
2. **Deploy Custom Rules ConfigMap**
   ```powershell
   kubectl apply -f manifests/falco-rules-configmap.yaml
   kubectl patch daemonset falco -n falco --type merge --patch-file manifests/falco-daemonset-patch.yaml
   kubectl rollout status daemonset falco -n falco
   ```

## Demo Flow
1. **Baseline Observation**
   - Describe Falco daemonset to ensure pods are running.
   - Tail Falco logs:
     ```powershell
     kubectl logs -n falco ds/falco -f
     ```
2. **Trigger Suspicious Behavior**
   - Launch `manifests/trigger-pod.yaml`.
   - Pod executes script writing to `/etc/shadow` then sleeps.
3. **Capture Alert**
   - Observe Falco log entry matching custom rule `Write Below Etc Demo`.
   - (Optional) Forward alert to Slack or create Jira ticket via Falcosidekick.
4. **Cleanup**
   - Delete trigger pod and ConfigMap.
   - Optionally uninstall Falco.

## Files & Directories
| Path | Description |
|------|-------------|
| `falco/write-below-etc.yaml` | Custom Falco rule for demo |
| `manifests/falco-rules-configmap.yaml` | ConfigMap packaging custom rule |
| `manifests/trigger-pod.yaml` | Pod that writes to `/etc` to trigger alert |
| `scripts/run-demo.ps1` | Helper script to automate trigger and log collection |

## Verification Checklist
- [ ] Falco daemonset running with eBPF driver.
- [ ] Custom rule visible in Falco logs during startup.
- [ ] Trigger pod causes Falco alert with `Write Below Etc Demo` output.
- [ ] Alert contains pod namespace/name for correlation.

## Cleanup
```powershell
kubectl delete -f manifests/trigger-pod.yaml --ignore-not-found
kubectl delete -f manifests/falco-rules-configmap.yaml --ignore-not-found
helm uninstall falco -n falco
kubectl delete namespace falco --ignore-not-found
```

## Next Steps
- Send alerts to Falcosidekick and integrate with Slack or Teams.
- Pair runtime alerts with automatic network quarantine (link to Groot demo).
- Expand rule set to include DNS exfiltration or reverse shell detection.
