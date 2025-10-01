# Image Hardening Demo (Rocket)

## Purpose
Compare vulnerability surface area between an "as-built" image and a hardened multi-stage, non-root alternative.

## Outcomes
- Quantify vulnerability reduction using Trivy before/after.
- Highlight removal of build-time tools from final image.
- Enforce non-root execution and restricted capabilities.

## Prerequisites
- Docker / container runtime
- `trivy`
- Optional: `grype` for cross-validation

## Demo Flow

### 🚀 **Automated Demo** (Recommended)
Run the complete demo with a single command:

**Linux/macOS (Bash):**
```bash
./scripts/run-demo.sh
```

**Windows (PowerShell):**
```powershell
./scripts/run-demo.ps1
```

### 🔧 **Manual Steps** (Optional)
1. **Baseline Build**
   ```bash
   docker build -f dockerfiles/Dockerfile.before -t guardian-demo:before .
   trivy image guardian-demo:before > reports/before.txt
   ```
2. **Hardened Build**
   ```bash
   docker build -f dockerfiles/Dockerfile.after -t guardian-demo:after .
   trivy image guardian-demo:after > reports/after.txt
   ```
3. **Compare Results**
   ```bash
   docker images guardian-demo
   # Review reports/demo-results.txt for comprehensive analysis
   ```

## Files & Directories
| Path | Description |
|------|-------------|
| `dockerfiles/Dockerfile.before` | Baseline image (single stage, root user) |
| `dockerfiles/Dockerfile.after` | Hardened distroless multi-stage build |
| `app/` | Demo Flask application source code |
| `reports/` | Stores scan outputs and comprehensive results |
| `scripts/run-demo.sh` | **Complete bash demo script (Linux/macOS)** |
| `scripts/run-demo.ps1` | **Complete PowerShell demo script (Windows)** |
| `scripts/compare-vulns.ps1` | Legacy comparison script |
| `scripts/README.md` | Detailed script documentation |

## Verification Checklist
- [ ] Before scan contains HIGH/CRITICAL vulnerabilities.
- [ ] After scan shows reduced severity counts.
- [ ] Hardened container runs as non-root and rejects shell access.
- [ ] Diff script prints improvement summary.

## Cleanup
```powershell
docker image rm guardian-demo:before guardian-demo:after -f
Remove-Item reports/* -Force
```

## Next Steps
- Add Docker Bench or Dockle score comparison.
- Integrate digest pinning and build provenance attestation.
