# Project Context

- **Project:** container-security
- **Created:** 2026-05-30
- **Requested by:** Chris Ayers

## Core Context

Nebula — Demo/QA Validator. Cross-cutting demo quality assurance — clean-room validation that every demo boots from a fresh cluster and passes, accurate prerequisites, smoke tests, and verified cross-demo handoffs.

## Recent Updates

📌 Joined 2026-05-30 as the cross-cutting Demo/QA Validator (Guardians of the Galaxy cast), per the team-structure review.

## Learnings

Initial setup complete.
- 2026-05-30: Cross-platform/architecture batch merged: reinforce shared kind+Calico setup-once/teardown-when-finished lifecycle, working .sh/.ps1 script twins, and macOS arm64/amd64 + Windows amd64/arm64 portability.

### 2026-06-03T13:37:10.790+02:00 — Clean-room Windows validation
- Bootstrap passed on kind v0.32.0 / Kubernetes v1.36.1 with Calico v3.32.0 and registry on 127.0.0.1:5000.
- Demo results: Demo 3 and Demo 5 passed; Demos 1, 2, 4, and 6 failed clean-room validation.
- Newly observed prereq gaps: helm, syft, cosign, grype, falco, jq, make, and Demo 2 `cosign.key` were absent; trivy was present.
- Repeatable script issues: Demo 1 PowerShell image tag becomes `/guardian-demo:*` with empty registry; Demo 2 and Demo 6 PowerShell scripts assume execution from `scripts` rather than README/demo root.
- Cleanup quality issue: Demo 2 and Demo 3 cleanup scripts delete tracked artifacts/reports; tracked files were restored after validation to avoid leaving destructive worktree changes.
- 2026-06-03T14:08:23.649+02:00: Validation fix cycle: first pass recorded 2 PASS (Demos 3,5) and 4 FAIL (Demos 1,2,4,6); fixes landed for Demos 1,2,6 and environment tooling, with re-validation pending.
