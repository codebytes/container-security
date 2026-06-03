# Project Context

- **Project:** container-security
- **Created:** 2026-05-30
- **Requested by:** Chris Ayers

## Core Context

Star-Lord — Lead / Policy Orchestration. Admission control and policy enforcement — Kyverno, OPA/Gatekeeper, Cosign signature verification at admission. As Lead, owns scope, structure, content review, and decisions.

## Recent Updates

📌 Team initialized on 2026-05-30 (Guardians of the Galaxy cast).

## Learnings

Initial setup complete.
- 2026-05-30: Completed review of assigned slides/demo layer for the full slides-demos-team-structure review.
- 2026-06-03: Demo 1 Windows build exposed the empty-registry tag bug (`/guardian-demo:*`). Fixed build scripts to emit plain local tags when no registry is set, fail fast on Docker build errors, and made run-demo call build with an explicit empty registry so environment leftovers do not drift manifests from local tags. Other demos with optional registry prefixes should use the same conditional-tag pattern.
- 2026-06-03T14:08:23.649+02:00: Validation fix cycle: Demo 1 moved from Nebula FAIL to Star-Lord smoke PASS after plain-tag/fail-fast fixes; full suite still awaits re-validation.
