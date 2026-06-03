# Zero-Trust Networking Demo (Groot)

> **Uses the shared cluster.** Set up once with
> [`scripts/setup-kind-cluster.sh`](../../scripts/setup-kind-cluster.sh) and tear
> down with [`scripts/teardown-kind-cluster.sh`](../../scripts/teardown-kind-cluster.sh).
> See [docs/CLUSTER-SETUP.md](../../docs/CLUSTER-SETUP.md). This demo needs Calico
> enforcement, which the shared kind cluster provides — no per-demo cluster setup.

## Purpose
Demonstrate deny-by-default Kubernetes NetworkPolicies that explicitly allow service-to-service traffic while blocking unauthorized access attempts.

## Outcomes
- Deploy a simple three-tier demo (frontend → api → db).
- Apply default deny policies for namespace ingress/egress.
- Define explicit allow rules for approved flows.
- Validate blocked traffic using curl test pod (`curlimages/curl`).

## Prerequisites
- Kubernetes cluster with `kubectl` access.
- `kubectl` v1.25+.
- **A NetworkPolicy-enforcing CNI** (e.g., Calico or Cilium).
  > ⚠️ **Network policies fail open without an enforcing CNI.** Clusters such as
  > Docker Desktop Kubernetes accept `NetworkPolicy` objects but do **not** enforce
  > them, so "blocked" traffic still flows and the demo only *simulates* Zero Trust.
  > `scripts/run-demo.sh` detects a missing policy controller and warns that it is
  > running in simulation mode.
  >
  > For real enforcement, create a kind cluster with Calico using
  > [`../../scripts/setup-kind-cluster.sh`](../../scripts/setup-kind-cluster.sh),
  > then switch context:
  > ```bash
  > ../../scripts/setup-kind-cluster.sh
  > kubectl config use-context kind-container-security
  > ```
- Optional: `stern` or `kubetail` for log tails.

## Environment Preparation
1. Create namespace:
   ```powershell
   kubectl create namespace demo-groot
   ```
2. Deploy demo services and baseline policies:
   ```powershell
   kubectl apply -f manifests/base-services.yaml
   kubectl apply -f manifests/default-deny.yaml
   kubectl apply -f manifests/allow-policies.yaml
   ```

## Demo Flow
1. **Verify Healthy Flow**
   - Port-forward frontend: `kubectl port-forward svc/frontend -n demo-groot 8080:80`.
   - Access `http://localhost:8080` to ensure chain works.
2. **Test Blocked Traffic**
   - Launch `manifests/tester-pod.yaml`.
   - Run:
     ```powershell
     kubectl exec -n demo-groot tester -- curl -sS api:8080/get
     kubectl exec -n demo-groot tester -- curl -sS db:5432
     ```
   - Expect first command to fail (deny) and second to fail (deny); only frontend→api→db should succeed.
3. **Allow Specific Diagnostic**
   - Apply `manifests/allow-tester-api.yaml` to temporarily permit tester → api.
   - Re-run curl to show targeted allowance.
4. **Cleanup**
   - Delete namespace or revoke temp policy.

## Files & Directories
| Path | Description |
|------|-------------|
| `manifests/base-services.yaml` | Deploy frontend, api, db deployments/services |
| `manifests/default-deny.yaml` | Namespace-wide deny policies |
| `manifests/allow-policies.yaml` | Explicit allow rules for legitimate flows |
| `manifests/tester-pod.yaml` | curl pod for validation (`curlimages/curl`) |
| `manifests/allow-tester-api.yaml` | Temporary diagnostic allowance |
| `scripts/run-demo.sh` / `scripts/run-demo.ps1` | Automates the test sequence. Set `DEMO_AUTOMATED=true` for non-interactive Bash runs. |

## Verification Checklist
- [ ] Default deny policies applied (no cross-pod traffic without allow).
- [ ] Frontend can reach API; API can reach DB.
- [ ] Tester pod initially blocked from API/DB.
- [ ] Temporary policy allows only intended traffic.

## Cleanup
```powershell
kubectl delete namespace demo-groot --ignore-not-found
```

## Next Steps
- Implement DNS and egress restrictions.
- Add Layer 7 policy via service mesh (e.g., Istio AuthorizationPolicy).
- Mirror network policy alerts into Falco or Cilium Hubble for observability.
