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
1. **Create namespaces**

   The trigger pod runs in `demo-drax`, while Falco runs in `falco`. Create both:
   ```powershell
   kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f -
   kubectl create namespace demo-drax --dry-run=client -o yaml | kubectl apply -f -
   ```
2. **Install Falco with the custom rule (Helm `customRules`)**

   The demo's custom rule is delivered through the Helm chart's `customRules`
   value (see `manifests/falco-values.yaml`). The chart renders it into a
   ConfigMap and mounts it where Falco actually loads rules
   (`/etc/falco/rules.d`). This is the single supported delivery path — do not
   hand-roll a ConfigMap + DaemonSet patch (it drifts on the next `helm upgrade`
   and mounts into a subdirectory Falco does not read).
   ```powershell
   helm repo add falcosecurity https://falcosecurity.github.io/charts
   helm repo update
   helm upgrade --install falco falcosecurity/falco \
     --namespace falco \
     --values manifests/falco-values.yaml \
     --wait
   ```

## Demo Flow
1. **Baseline Observation**
   - Describe Falco daemonset to ensure pods are running.
   - Tail Falco logs:
     ```powershell
     kubectl logs -n falco ds/falco -f
     ```
2. **Trigger Suspicious Behavior**
   - Launch `manifests/trigger-pod.yaml` (runs in the `demo-drax` namespace):
     ```powershell
     kubectl apply -f manifests/trigger-pod.yaml
     ```
   - Pod executes script writing to `/etc/shadow` then sleeps.
3. **Capture Alert**
   - Observe Falco log entry matching custom rule `Write Below Etc Demo`.
   - (Optional) Forward alert to Slack or create Jira ticket via Falcosidekick.
4. **Cleanup**
   - Delete trigger pod (`kubectl delete -f manifests/trigger-pod.yaml`).
   - Optionally uninstall Falco (removes the custom rule with it).

## Files & Directories
| Path | Description |
|------|-------------|
| `manifests/falco-values.yaml` | Helm values — **single source of truth** for the custom Falco rule (delivered via `customRules`) |
| `manifests/trigger-pod.yaml` | Pod (namespace `demo-drax`) that writes to `/etc` to trigger the alert |
| `scripts/run-demo.sh` / `scripts/run-demo.ps1` | Helper scripts to automate install, trigger and log collection. Set `DEMO_AUTOMATED=true` for non-interactive Bash runs. |
| `scripts/cleanup.sh` | Tear down the trigger pod and Falco release |

## Verification Checklist
- [ ] Falco daemonset running with modern eBPF driver.
- [ ] Custom rule visible in Falco logs during startup.
- [ ] Trigger pod causes Falco alert with `Write Below Etc Demo` output.
- [ ] Alert contains pod namespace/name for correlation.

## Cleanup
```powershell
kubectl delete -f manifests/trigger-pod.yaml --ignore-not-found
kubectl delete namespace demo-drax --ignore-not-found
helm uninstall falco -n falco
kubectl delete namespace falco --ignore-not-found
```

## Next Steps
- Send alerts to Falcosidekick and integrate with Slack or Teams.
- Pair runtime alerts with automatic network quarantine (link to Groot demo).
- Expand rule set to include DNS exfiltration or reverse shell detection.
