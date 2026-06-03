# Project Context

- **Project:** container-security
- **Created:** 2026-05-30
- **Requested by:** Chris Ayers

## Core Context

Gamora — Supply Chain Integrity. Software supply chain integrity — SBOM generation (Syft), vulnerability scanning (Grype/Trivy), artifact signing and verification (Cosign/Sigstore), provenance.

## Recent Updates

📌 Team initialized on 2026-05-30 (Guardians of the Galaxy cast).

## Learnings

Initial setup complete.
- 2026-05-30: Completed review of assigned slides/demo layer for the full slides-demos-team-structure review.
- 2026-05-30: Cross-platform/architecture batch merged: reinforce shared kind+Calico setup-once/teardown-when-finished lifecycle, working .sh/.ps1 script twins, and macOS arm64/amd64 + Windows amd64/arm64 portability.
- 2026-06-03: Demo 2 pipeline scripts now resolve paths from their own script directory, fail fast on missing supply-chain prerequisites/key material, and keep cleanup away from tracked SBOM artifacts.
- 2026-06-03T14:08:23.649+02:00: Validation fix cycle: Demo 2 FAIL was addressed with script-root pathing, Syft/Cosign/key preflight, artifact relocation, and cleanup tightening; re-validation remains pending.
