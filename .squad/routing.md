# Work Routing

How to decide who handles what.

## Routing Table

| Work Type | Route To | Examples |
|-----------|----------|----------|
| Policy / admission control | Star-Lord | Kyverno, OPA/Gatekeeper, Cosign verify at admission (demo 1) |
| Supply chain integrity | Gamora | SBOM (Syft), scanning (Grype/Trivy), signing (Cosign) (demo 2) |
| Image hardening | Rocket | Distroless/minimal images, Dockerfile hardening, Trivy diffs (demo 3) |
| Runtime detection | Drax | Falco rules, behavioral detection, escape/cryptojacking triggers (demo 4) |
| Zero-trust networking | Groot | Deny-by-default NetworkPolicies, Calico/Cilium (demo 5) |
| Security observability | Mantis | OTEL telemetry, Falco alert correlation, dashboards (demo 6) |
| Demo/QA validation | Nebula | Clean-room "fresh cluster runs all 6 demos", prereqs checklist, smoke tests, cross-demo handoffs |
| Slides / narrative / docs | Star-Lord + relevant layer owner | Marp deck, README, story flow |
| Code review & decisions | Star-Lord | Review work, check quality, scope and trade-offs |
| Scope & priorities | Star-Lord | What to build next, trade-offs, decisions |
| Session logging | Scribe | Automatic — never needs routing |
| RAI review | Rai | Content safety, bias checks, credential detection, ethical review |

## Issue Routing

| Label | Action | Who |
|-------|--------|-----|
| `squad` | Triage: analyze issue, assign `squad:{member}` label | Star-Lord |
| `squad:{name}` | Pick up issue and complete the work | Named member |

### How Issue Assignment Works

1. When a GitHub issue gets the `squad` label, Star-Lord (Lead) triages it — analyzing content, assigning the right `squad:{member}` label, and commenting with triage notes.
2. When a `squad:{member}` label is applied, that member picks up the issue in their next session.
3. Members can reassign by removing their label and adding another member's label.
4. The `squad` label is the "inbox" — untriaged issues waiting for Lead review.

## Rules

1. **Eager by default** — spawn all agents who could usefully start work, including anticipatory downstream work.
2. **Scribe always runs** after substantial work, always as `mode: "background"`. Never blocks.
3. **Quick facts → coordinator answers directly.** Don't spawn an agent for "what port does the server run on?"
4. **When two agents could handle it**, pick the one whose domain is the primary concern.
5. **"Team, ..." → fan-out.** Spawn all relevant agents in parallel as `mode: "background"`.
6. **Anticipate downstream work.** If a feature is being built, spawn the tester to write test cases from requirements simultaneously.
7. **Issue-labeled work** — when a `squad:{member}` label is applied to an issue, route to that member. The Lead handles all `squad` (base label) triage.
