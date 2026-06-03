# Supply Chain Trust Demo (Gamora)

## Purpose
Illustrate a secure image pipeline that produces an SBOM, scans for vulnerabilities, signs the artifact, stores attestations, and enforces signature & severity thresholds before deployment.

## Outcomes
- Generate SBOMs as build artifacts.
- Fail builds when severity thresholds are exceeded.
- Sign images with Cosign and store attestations.
- Enforce signature verification + vulnerability policy at admission.

## Prerequisites
- Docker / container runtime (or `nerdctl`)
- `syft`, `trivy`, `cosign`
- Access to OCI registry supporting signatures (GitHub Container Registry, Harbor, etc.)
- Kubernetes cluster with Kyverno (reuse from policy demo) or Gatekeeper for admission policy.
- Optional: `make` for pipeline convenience.

> ⚠️ **macOS port 5000 / AirPlay Receiver collision.** On macOS, `localhost:5000`
> resolves to IPv6 `::1`, which **AirPlay Receiver / Control Center** binds (returns
> HTTP 403), while the local Docker registry listens only on IPv4 `127.0.0.1:5000`.
> Symptoms: `cosign`/`docker push` to `localhost:5000` fail intermittently. **The pipeline
> now defaults to `127.0.0.1:5000` to avoid this.** If you prefer `localhost:5000`, first
> **disable System Settings → General → AirDrop & Handoff → AirPlay Receiver**, then pass it
> explicitly (e.g. `./scripts/run-pipeline.sh localhost:5000`).
>
> This only affects **host-side** access. Inside the cluster, Kyverno and the kubelet
> reach the registry as `registry:5000` (kind network), which is unaffected.

## Scan gate behavior (informational by default)
The Trivy step is **informational by default** — it prints HIGH/CRITICAL findings but
does **not** hard-block the pipeline. With a live Trivy database, every practical base
image (including this demo's **distroless** final stage) reports some **unfixed base-OS
CVEs** (e.g. `zlib` `will_not_fix`), so a hard `--exit-code 1` gate would permanently
dead-end the demo before sign/verify/admission can run. The Dockerfile still rebases
onto `gcr.io/distroless/python3-debian12` (numeric `USER 65532`, no shell/package
manager) to genuinely minimize the attack surface, keeping the *scan → sign → verify →
admit* story honest. Set `STRICT_SCAN=1` (`$env:STRICT_SCAN='1'` in PowerShell) to
restore a hard, production-style gate.

## Key Pair Setup

Before running the demo, generate your own Cosign key pair:

```bash
cosign generate-key-pair
```

This creates `cosign.key` (private) and `cosign.pub` (public) in the current directory.

> ⚠️ **Never commit the PRIVATE key `cosign.key` to version control.** Only the private
> key is secret. The public key `cosign.pub` is **safe to share and is committed** in this
> demo so the Kyverno policy and `cosign verify` can validate signatures. The repository
> `.gitignore` excludes `cosign.key`; distribute `cosign.pub` freely (or via a secret
> manager if you prefer).

## Environment Variables
```bash
export DEMO_REGISTRY="127.0.0.1:5000"
export DEMO_IMAGE_NAME="guardian-demo-app"
export DEMO_TAG="v0.1.0-secure"
```

```powershell
$env:DEMO_REGISTRY="127.0.0.1:5000"
$env:DEMO_IMAGE_NAME="guardian-demo-app"
$env:DEMO_TAG="v0.1.0-secure"
```

> The pipeline **defaults to `127.0.0.1:5000`** (not `localhost:5000`) so cosign/`docker push`
> avoid the macOS AirPlay collision on `*:5000`. It is the **same** registry container the
> shared cluster wires up (`scripts/setup-kind-cluster.sh` publishes it on `127.0.0.1:5000`),
> reachable in-cluster as `registry:5000`.

## Demo Flow
### Option 1: Automated Pipeline (Bash)
```bash
# Run complete pipeline with defaults (secure image)
./scripts/run-pipeline.sh

# Run with custom parameters
./scripts/run-pipeline.sh localhost:5000 guardian-demo-app v0.1.0-secure

# Show help
./scripts/run-pipeline.sh --help
```

### Option 2: Automated Pipeline (PowerShell)
```powershell
# Run complete pipeline with defaults (secure image)
./scripts/run-pipeline.ps1

# Run with custom parameters  
./scripts/run-pipeline.ps1 -Registry "localhost:5000" -ImageName "guardian-demo-app" -Tag "v0.1.0-secure"
```

### Option 3: Manual Steps
1. **Build Application Image**
   - Use `pipeline/Dockerfile` to build the demo service.
   - Tag image as `$DEMO_REGISTRY/$DEMO_IMAGE_NAME:$DEMO_TAG`.
2. **Generate SBOM**
   - Run `syft scan` to create `attestations/sbom.json`.
   - Upload SBOM to artifact storage (or commit).
3. **Scan for Vulnerabilities**
   - Run `trivy image` with `--exit-code 1 --severity HIGH,CRITICAL` to enforce gating.
       - Observe failure if threshold breached.
       - On success, label image metadata (or deployment) with `guardian.dev/last-scan=high-critical-clear`.
4. **Sign Image**
   - Use Cosign keyed signing (`cosign sign --key cosign.key`); output signature + attestations to `attestations/` and registry.
   - **cosign 3.x note:** cosign ≥3.0 defaults to the new OCI-1.1 *referrer* bundle format, which Kyverno's `verifyImages` reader cannot find (`no signatures found`). The pipeline scripts force the **legacy `.sig`** format (`--use-signing-config=false --new-bundle-format=false --tlog-upload=false`, each added only if the installed cosign supports it) so signatures round-trip through both `cosign verify` and Kyverno.
   - Verify with the public key: `cosign verify --key cosign.pub`.
5. **Verify Admission (signed-vs-unsigned discrimination, in-cluster)**

   Run the **fully automated** admission demo (no manual kubectl needed):

   ```bash
   # Bash (mac/Linux)
   ./scripts/setup-admission.sh            # defaults: 127.0.0.1:5000 guardian-demo-app v0.1.0-secure
   ```
   ```powershell
   # PowerShell (Windows)
   ./scripts/setup-admission.ps1
   ```

   `setup-admission` automatically: installs Kyverno if absent **and enables
   `--allowInsecureRegistry=true`** (Kyverno ships it `false`, so it can't pull from the
   plain-HTTP local registry); injects the cosign public key as a secret; applies the
   namespace + policy; deploys the **SIGNED** image (EXPECT ADMITTED); then builds a
   genuinely **DISTINCT UNSIGNED** image (cosign signs the *digest*, not the tag, so a
   re-tag would still be signed), pushes it, and deploys it (EXPECT REJECTED —
   `no signatures found`).

   This needs the shared **kind + Calico** cluster and its **kind-network registry**
   (see [`docs/CLUSTER-SETUP.md`](../../docs/CLUSTER-SETUP.md)). The host pushes/signs to
   `127.0.0.1:5000`; in-cluster the **same** registry is reachable as `registry:5000`.
   Kyverno's signature lookup resolves DNS through the *cluster* (not containerd's
   `hosts.toml` alias), so the policy and demo deployments reference `registry:5000/...`.

   <details><summary>Manual equivalent (for reference)</summary>

   ```bash
   # Kyverno must allow the plain-HTTP local registry (ships disabled):
   kubectl -n kyverno patch deploy kyverno-admission-controller --type=json \
     -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--allowInsecureRegistry=true"}]'

   # a) Inject the SIGNING public key so Kyverno can verify (no private key in git):
   kubectl -n kyverno create secret generic guardian-cosign-pub \
     --from-file=cosign.pub=cosign.pub --dry-run=client -o yaml | kubectl apply -f -

   # b) Create the demo namespace + enforce policy:
   kubectl apply -f manifests/demo-namespace.yaml -f manifests/policy-require-signature.yaml

   # c) SIGNED image -> EXPECT ADMITTED:
   kubectl apply -f manifests/deploy-signed.yaml
   kubectl -n demo-gamora rollout status deploy/guardian-signed

   # d) UNSIGNED image -> EXPECT REJECTED (build a genuinely DISTINCT image, do NOT sign):
   docker build -f pipeline/Dockerfile --label demo.variant=unsigned --no-cache \
     -t 127.0.0.1:5000/guardian-demo-app:v0.1.0-unsigned .
   docker push 127.0.0.1:5000/guardian-demo-app:v0.1.0-unsigned   # do NOT cosign sign it
   kubectl apply -f manifests/deploy-unsigned.yaml                # admission DENIED by Kyverno
   ```
   </details>

   The policy is `failureAction: Enforce`, `mutateDigest: false`, `required: true`, so a
   valid signature is **admitted** and a missing/invalid one is **rejected**. Both demo
   deployments carry `runAsNonRoot: true` **paired with the numeric** `runAsUser: 65532`
   (matching the distroless image's `USER 65532`) — a non-numeric/root USER would fail the
   kubelet's non-root check regardless of signature.

## Files & Directories
| Path | Description |
|------|-------------|
| `app/` | Minimal demo service (Python) used to build container |
| `pipeline/Dockerfile` | Multi-stage build producing final image |
| `pipeline/Makefile` | Convenience targets for build → sbom → scan → sign |
| `scripts/run-pipeline.sh` | Bash automation script for the complete pipeline |
| `scripts/run-pipeline.ps1` | PowerShell automation script for the complete pipeline |
| `scripts/setup-admission.sh` | Bash: automated in-cluster admission demo (Kyverno insecure-registry enable + signed ADMITTED / unsigned REJECTED) |
| `scripts/setup-admission.ps1` | PowerShell twin of `setup-admission.sh` |
| `scripts/cleanup.sh` / `scripts/cleanup.ps1` | Remove demo artifacts, images, namespace, ClusterPolicy, and the cosign public-key secret |
| `attestations/` | SBOMs and Cosign bundles |
| `manifests/policy-require-signature.yaml` | Kyverno verifyImages (Enforce) + scan-label policy, scoped to `demo-gamora` |
| `manifests/demo-namespace.yaml` | `demo-gamora` namespace for the admission demo |
| `manifests/deploy-signed.yaml` | Signed image Deployment (expect ADMITTED) |
| `manifests/deploy-unsigned.yaml` | Unsigned image Deployment (expect REJECTED) |

## Verification Checklist
- [ ] SBOM file generated and stored in `attestations/sbom.json`.
- [ ] Trivy scan passes with acceptable severity (or intentionally fails to demonstrate gating).
- [ ] Cosign signature and attestations exist (`cosign verify` success).
- [ ] Unsigned deployment rejected by admission controller.
- [ ] Signed deployment admitted and running.

## Cleanup
The cleanup scripts remove the demo namespace, ClusterPolicy, cosign public-key secret,
generated SBOMs, and demo images (idempotent; they do **not** remove the shared `registry`
container or the kind cluster — tear those down with `scripts/teardown-kind-cluster.{sh,ps1}`):

```bash
./scripts/cleanup.sh
```
```powershell
./scripts/cleanup.ps1
```

<details><summary>Manual equivalent</summary>

```bash
kubectl delete -f manifests/deploy-unsigned.yaml --ignore-not-found
kubectl delete -f manifests/deploy-signed.yaml --ignore-not-found
kubectl delete -f manifests/policy-require-signature.yaml --ignore-not-found
kubectl delete -f manifests/demo-namespace.yaml --ignore-not-found
kubectl -n kyverno delete secret guardian-cosign-pub --ignore-not-found
rm -f attestations/sbom.json
```
```powershell
kubectl delete -f manifests/deploy-unsigned.yaml --ignore-not-found
kubectl delete -f manifests/deploy-signed.yaml --ignore-not-found
kubectl delete -f manifests/policy-require-signature.yaml --ignore-not-found
kubectl delete -f manifests/demo-namespace.yaml --ignore-not-found
kubectl -n kyverno delete secret guardian-cosign-pub --ignore-not-found
Remove-Item attestations/sbom.json -Force -ErrorAction SilentlyContinue
```
</details>

## Next Steps
- Automate SBOM & signing in GitHub Actions with `cosign attest`.
- Publish SBOM to Dependency Track or GUAC.
- Add provenance attestation via `cosign attest --predicate`.
