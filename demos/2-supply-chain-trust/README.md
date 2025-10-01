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

## Environment Variables
```bash
export DEMO_REGISTRY="localhost:5000"
export DEMO_IMAGE_NAME="guardian-demo-app"
export DEMO_TAG="v0.1.0-secure"
```

```powershell
$env:DEMO_REGISTRY="localhost:5000"
$env:DEMO_IMAGE_NAME="guardian-demo-app"
$env:DEMO_TAG="v0.1.0-secure"
```

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
   - Use Cosign keyless signing; output signature + attestations to `attestations/` and registry.
5. **Verify Admission**
   - Apply `manifests/policy-require-signature.yaml`.
   - Attempt to deploy unsigned digest (expect denial).
   - Deploy signed digest (expect success).

## Files & Directories
| Path | Description |
|------|-------------|
| `app/` | Minimal demo service (Python) used to build container |
| `pipeline/Dockerfile` | Multi-stage build producing final image |
| `pipeline/Makefile` | Convenience targets for build → sbom → scan → sign |
| `scripts/run-pipeline.sh` | Bash automation script for the complete pipeline |
| `scripts/run-pipeline.ps1` | PowerShell automation script for the complete pipeline |
| `attestations/` | SBOMs and Cosign bundles |
| `manifests/policy-require-signature.yaml` | Kyverno verifyImages + scan label policy |

## Verification Checklist
- [ ] SBOM file generated and stored in `attestations/sbom.json`.
- [ ] Trivy scan passes with acceptable severity (or intentionally fails to demonstrate gating).
- [ ] Cosign signature and attestations exist (`cosign verify` success).
- [ ] Unsigned deployment rejected by admission controller.
- [ ] Signed deployment admitted and running.

## Cleanup
```powershell
kubectl delete -f manifests/policy-require-signature.yaml --ignore-not-found
remove-item attestions\* -Force
```

## Next Steps
- Automate SBOM & signing in GitHub Actions with `cosign attest`.
- Publish SBOM to Dependency Track or GUAC.
- Add provenance attestation via `cosign attest --predicate`.
