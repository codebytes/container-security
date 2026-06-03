# Zero-Trust Networking Demo (Groot)

> **Uses the shared cluster.** Set up once with
> [`scripts/setup-kind-cluster.sh`](../../scripts/setup-kind-cluster.sh) and tear
> down with [`scripts/teardown-kind-cluster.sh`](../../scripts/teardown-kind-cluster.sh).
> See [docs/CLUSTER-SETUP.md](../../docs/CLUSTER-SETUP.md). This demo needs Calico
> enforcement, which the shared kind cluster provides — no per-demo cluster setup.

## Purpose
Demonstrate deny-by-default Kubernetes NetworkPolicies that explicitly allow service-to-service traffic while blocking unauthorized access attempts.

## Outcomes
- Deploy simple frontend, api, and db workloads.
- Apply default deny policies for namespace ingress/egress.
- Define explicit allow rules for approved frontend→api and api→db policy paths.
- Validate allowed and blocked paths using labeled probe pods (`curlimages/curl` and `postgres:16-alpine`).

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
2. Deploy demo services first to show the default flat network posture:
   ```powershell
   kubectl apply -f manifests/base-services.yaml
   ```

## Demo Flow
1. **Show the Baseline Risk**
   - Deploy the three-tier app with no NetworkPolicies yet.
   - Explain that Kubernetes networking is flat by default: there is no policy boundary until Groot creates one.
2. **Apply Default Deny**
   - Apply namespace-wide deny policies:
     ```powershell
     kubectl apply -f manifests/default-deny.yaml
     ```
   - At this point, all ingress/egress is denied unless explicitly allowed.
3. **Allow Approved Service Paths**
   - Apply allow rules for frontend→api, api→db, and DNS:
     ```powershell
     kubectl apply -f manifests/allow-policies.yaml
     ```
   - These rules permit the approved policy paths; the stock demo workloads do not implement a real frontend→api→db application call chain.
   - Optional UI view: `kubectl port-forward svc/frontend -n demo-groot 8080:80`, then open `http://localhost:8080`.
4. **Test Blocked and Allowed Traffic**
   - Launch `manifests/tester-pod.yaml`.
   - Run blocked checks from the unauthorized tester pod/label:
     ```powershell
     kubectl exec -n demo-groot tester -- curl -sS --connect-timeout 3 api:8080/get
     kubectl run tester-db-probe -n demo-groot --rm -i --restart=Never --labels=app=tester --image=postgres:16-alpine --command -- pg_isready -h db -p 5432 -U postgres -t 3
     ```
   - Run allowed checks from pods with the approved labels:
     ```powershell
     kubectl run frontend-probe -n demo-groot --rm -i --restart=Never --labels=app=frontend --image=curlimages/curl:8.8.0 --command -- curl -sS --connect-timeout 3 api:8080/get
     kubectl run api-db-probe -n demo-groot --rm -i --restart=Never --labels=app=api --image=postgres:16-alpine --command -- pg_isready -h db -p 5432 -U postgres -t 3
     ```
   - Expect tester→api and tester→db to fail, while frontend-labeled→api and api-labeled→db probes succeed.
5. **Allow Specific Diagnostic**
   - Apply `manifests/allow-tester-api.yaml` to temporarily permit tester → api.
   - Re-run curl to show targeted allowance.
6. **Cleanup**
   - Delete namespace or revoke temp policy.

## Files & Directories
| Path | Description |
|------|-------------|
| `manifests/base-services.yaml` | Deploy frontend, api, db deployments/services |
| `manifests/default-deny.yaml` | Namespace-wide deny policies |
| `manifests/allow-policies.yaml` | Explicit allow rules for legitimate flows |
| `manifests/tester-pod.yaml` | unauthorized curl pod for tester→api validation (`curlimages/curl`) |
| `manifests/allow-tester-api.yaml` | Temporary diagnostic allowance |
| `scripts/run-demo.sh` / `scripts/run-demo.ps1` | Automates the test sequence. Set `DEMO_AUTOMATED=true` for non-interactive Bash runs. |

## Verification Checklist
- [ ] Default deny policies applied (no cross-pod traffic without allow).
- [ ] Frontend-labeled probe can reach API; API-labeled probe can reach DB.
- [ ] Tester pod/label initially blocked from API/DB.
- [ ] Temporary policy allows only intended traffic.

## Cleanup
```powershell
kubectl delete namespace demo-groot --ignore-not-found
```

## Next Steps
- Implement DNS and egress restrictions.
- Add Layer 7 policy via service mesh (e.g., Istio AuthorizationPolicy).
- Mirror network policy alerts into Falco or Cilium Hubble for observability.
