# Project Context

- **Project:** container-security
- **Created:** 2026-05-30
- **Requested by:** Chris Ayers

## Core Context

Mantis — Security Observability. Security observability — OpenTelemetry telemetry, Falco alert correlation, signal pipelines, dashboards and detection visibility.

## Recent Updates

📌 Team initialized on 2026-05-30 (Guardians of the Galaxy cast).

## Learnings

Initial setup complete.
- 2026-05-30: Completed review of assigned slides/demo layer for the full slides-demos-team-structure review.
- 2026-05-30: Cross-platform/architecture batch merged: reinforce shared kind+Calico setup-once/teardown-when-finished lifecycle, working .sh/.ps1 script twins, and macOS arm64/amd64 + Windows amd64/arm64 portability.
- 2026-06-03: Demo 6 run scripts now resolve paths from their script directories, fail fast on missing docker/kubectl/helm, and require the demo 4 Falco Helm handoff before deployment.
- 2026-06-03T14:08:23.649+02:00: Validation fix cycle: Demo 6 FAIL was addressed with script-root pathing, docker/kubectl/helm preflight, and explicit demo 4 Falco handoff guidance; re-validation remains pending.
