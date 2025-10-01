# Zero-Trust Networking Demo (Groot)

## Purpose
Demonstrate deny-by-default Kubernetes NetworkPolicies that explicitly allow service-to-service traffic while blocking unauthorized access attempts.

## Outcomes
- Deploy a simple three-tier demo (frontend → api → db).
- Apply default deny policies for namespace ingress/egress.
- Define explicit allow rules for approved flows.
- Validate blocked traffic using busybox test pod.

## Prerequisites
- Kubernetes cluster with `kubectl` access.
- `kubectl` v1.25+.
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
     kubectl exec -n demo-groot tester -- curl -sS api:8080/health
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
| `manifests/tester-pod.yaml` | Busybox pod for validation |
| `manifests/allow-tester-api.yaml` | Temporary diagnostic allowance |
| `scripts/run-demo.ps1` | Automates test sequence |

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
