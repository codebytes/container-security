# Squad Decisions

## Cross-Cutting Conventions

### securityContext — numeric non-root UID (REPO-WIDE, FIRST-CLASS)

**2026-05-30T10:30:00-04:00 — User directive (Chris Ayers via Copilot), derived from the Nebula validation run.**

- **ALWAYS pair `runAsNonRoot: true` with a numeric `runAsUser` (canonical UID/GID `65532`).** A non-numeric image `USER` (e.g. `USER app`) or a root-default image does NOT satisfy the kubelet's `runAsNonRoot` check — the pod fails to start with `CreateContainerConfigError` ("container has runAsNonRoot and image will run as root" / "image has non-numeric user … cannot verify user is non-root").
- Adopt Demo 3's correct distroless `USER 65532` pattern everywhere; the Dockerfile numeric `USER` and the manifest `runAsUser` must agree.
- This single convention resolved Demos 5 and 6 and the runtime gap in Demo 1 at once — it was the shared root cause of those failures.
- Exception: an image that genuinely must run as root (e.g. stock nginx binding privileged port 80) sets `runAsNonRoot: false` explicitly and drops all caps, adding only `NET_BIND_SERVICE`.

### cosign signature format for Kyverno verifyImages (legacy `.sig`)

**2026-05-30 — Confirmed by Nebula live re-validation (cosign v3.0.6 + current Kyverno).**

- cosign 3.x defaults to `--new-bundle-format=true` / `--use-signing-config=true`, storing signatures as an **OCI-1.1 referrer** (tag `sha256-<digest>`, type `https://sigstore.dev/cosign/sign/v1`). Kyverno's verifyImages reader only finds the **legacy** `sha256-<digest>.sig` and reports `no signatures found` → every image rejected (fail-closed-for-all).
- **Any cosign signing intended for Kyverno verification must force the legacy format:** `--use-signing-config=false --new-bundle-format=false --tlog-upload=false` (sign), `--insecure-ignore-tlog=true` (verify). Add each flag only if the installed cosign advertises it (version-guarded) so cosign 2.x still works.
- cosign signs the **digest**, not the tag; an "unsigned" variant must be a genuinely distinct build (different digest), not a re-tag.
- **A tlog-free signature (`cosign sign --tlog-upload=false`) requires the Kyverno policy to set `rekor.ignoreTlog: true`** under the key attestor — otherwise Kyverno v1.18 fails CLOSED for the SIGNED image too (`signature not found in transparency log`), so signed and unsigned are both rejected and discrimination is broken. Schema path: `spec.rules[].verifyImages[].attestors[].entries[].keys.rekor.ignoreTlog` (it is **`rekor.ignoreTlog`**, NOT `ctlog.ignoreTlog` — `keys.ctlog` only exposes `ignoreSCT/pubkey/tsaCertChain` and is rejected by strict decoding). Confirmed live on pass-3.

### Kyverno Helm chart `extraArgs` is a MAP, not a list

**2026-05-30 — Confirmed by Gamora `helm template` contrast + Nebula pass-3 live run (chart 3.8.1 / app v1.18.x).**

- The Kyverno chart's `admissionController.container.extraArgs` is a **map (key→value)**, not a list. Setting it with list-index form (`--set …extraArgs[0]="--allowInsecureRegistry=true"`) creates key `0`, rendered as the literal arg `--0=--allowInsecureRegistry=true` → Go's flag parser aborts (`flag provided but not defined: -0`) → admission controller **CrashLoopBackOff**.
- **Use the map form:** `--set admissionController.container.extraArgs.allowInsecureRegistry=true`. The chart appends extraArgs after its default `--allowInsecureRegistry=false`; Go's flag parser takes the **last** value, so the effective setting is `true`, and every rendered token is a defined flag.
- Any safety-net patch must use an **exact array-element match** (e.g. `jq -e 'any(.[]; . == "--allowInsecureRegistry=true")'`), not a substring `grep` (which the `--0=…` garbage satisfies, wrongly skipping the repair), and should **sanitize** bad state (drop `--0=*` and `--allowInsecureRegistry=false`) rather than blindly append.

### Local registry host & executable scripts (portability)

**2026-05-30 — Confirmed by Nebula live re-validation (macOS arm64).**

- **Default local registry is `127.0.0.1:5000`, not `localhost:5000`.** On macOS, AirPlay Receiver (ControlCenter) binds `*:5000`; `localhost`→`::1` hits AirPlay (403 `AirTunes`), while `127.0.0.1` hits the registry's IPv4 listener. The same container is reachable in-cluster as `registry:5000`. Use `--allow-http-registry` for plain-HTTP pushes.
- **All `.sh` scripts must be committed executable (git mode `100755`).** `run-demo.sh` invokes sibling scripts directly (`./scripts/build-images.sh`), so a non-executable bit causes `Permission denied` on a fresh clone. Stage with `git update-index --chmod=+x`. `.ps1` twins do not use the unix exec bit.

## Active Decisions

### 2026-05-30 — Lead/Policy (Star-Lord)
- Demo 1/README alignment is corrected: Demo 1 is Kyverno admission policy guardrails with simulated signed-image validation; real Cosign verification belongs to Demo 2.
- Kyverno policy fields are modernized from deprecated `validationFailureAction` to per-rule `validate.failureAction`.
- Non-root enforcement requires `runAsNonRoot: true`, not only denying explicit `runAsUser: 0`.
- Demo 1 run-demo step numbering and Kyverno troubleshooting commands are aligned.
- Slides now reconcile keyless-vs-keyed signing, numeric non-root UID guidance, updated dwell-time/OpenTelemetry maturity, and Falco/app correlation by pod/namespace/timestamp rather than trace ID.

### 2026-05-30 — Supply Chain Integrity (Gamora)
- Demo 2 standardizes on keyed Cosign signing and verification: `cosign sign --key cosign.key` and `cosign verify --key cosign.pub`.
- Demo 2 standardizes on `localhost:5000/guardian-demo-app` for scripts, Makefile defaults, and Kyverno `imageReferences`.
- Demo 2 run-pipeline scripts detect/reuse the shared kind-network registry when available; standalone registry creation is only a fallback with warning.
- Demo 2 cleanup is scoped to demo artifacts/images only and must not delete the shared `registry` container or the kind cluster.
- Public `cosign.pub` is intentionally shareable; private `cosign.key` remains secret/gitignored.
- Demo 2 admission is fully automated via a `setup-admission.{sh,ps1}` twin: installs Kyverno if absent and always patches `kyverno-admission-controller` with `--allowInsecureRegistry=true` (idempotent) so the verifier can reach the plain-HTTP registry — no manual patching.
- Demo 2 cleanup also removes the `demo-gamora` namespace, the `verify-supply-chain-signatures` ClusterPolicy, and the `kyverno/guardian-cosign-pub` secret, across `localhost:5000`/`127.0.0.1:5000`/`registry:5000` tags; it never touches the shared registry container or cluster.

### 2026-05-30 — Image Hardening (Rocket)
- Demo 3 vulnerability counting should parse real Trivy results (prefer JSON + `jq`) and keep report/demo/slides numbers from one source of truth.
- Demo 3 hardening should use Kubernetes-compatible non-root configuration, with slides reflecting numeric UID `65532` and the real ~99% CVE reduction/base-image bump.
- Demo 3 cleanup is scoped to `guardian-demo:baseline`, `guardian-demo:hardened`, and `reports/*.txt`; it does not touch the shared cluster or registry.

### 2026-05-30 — Runtime Detection (Drax)
- Demo 4 custom Falco rules are standardized on Helm `customRules`; the old ConfigMap/DaemonSet patch flow is retired.
- `manifests/falco-values.yaml` is the single rule source of truth; duplicate rule files/configmap/patch artifacts are removed.
- Falco rule matching uses `fd.name startswith "/etc/"` to avoid `/etcfoo` false positives while preserving subdirectory detection.
- Demo 4 cleanup removes `demo-drax`, trigger pod artifacts, and the Falco release/namespace fallback only; it does not touch the shared cluster or registry.
- Demo 4 cleanup deletes the `falco` namespace unconditionally (idempotent) after uninstall, so neither the helm nor manual path orphans an empty namespace.

### 2026-05-30 — Zero-Trust Networking (Groot)
- Demo 5 requires a NetworkPolicy-enforcing CNI; Docker Desktop built-in Kubernetes accepts policies but fails open, so enforcement demos should use the shared kind+Calico cluster.
- Demo 5 allowed-path testing uses a labeled `curlimages/curl:8.8.0` probe pod instead of executing curl inside the frontend image.
- Demo 5 probes use real httpbin-compatible `/get` endpoints, not `/health`.
- Demo 5 replaces amd64-only `kennethreitz/httpbin` with multi-arch `ghcr.io/mccutchen/go-httpbin:v2.15.0`; API container and NetworkPolicy ports move from 80 to 8080 while Service port/probes remain `api:8080`.
- Demo 5 cleanup removes only the `demo-groot` namespace.

### 2026-05-30 — Security Observability (Mantis)
- Demo 6 must honestly represent signal coverage: app telemetry and Falco events correlate by pod/namespace/timestamp, not shared trace IDs.
- Collector Prometheus exposure and Falco-to-collector ingestion claims must match the actual implementation.
- OpenTelemetry is documented as CNCF Incubating; stale dwell-time statistics are refreshed.
- Demo 6 cleanup removes the demo namespace, falcosidekick release, and `guardian-telemetry` image while preserving Falco and the shared cluster/registry.

### 2026-05-30T09:00:08-04:00 — Demo target environment directive
- Local Docker Desktop Kubernetes is an acceptable baseline assumption for demos 1–4 and 6, using `kubectl port-forward` rather than LoadBalancer/Ingress.
- Docker Desktop's built-in CNI does not enforce NetworkPolicies; Demo 5 must clearly warn that it only simulates zero trust there unless Calico/Cilium is installed.
- For genuine NetworkPolicy enforcement and cross-demo consistency, the primary path is the shared kind+Calico cluster.

### 2026-05-30T09:22:19-04:00 — Cross-platform script parity directive
- Every script must ship as both a working `.sh` mac/Linux twin and a working `.ps1` Windows twin.
- Twins must provide functional parity, not stubs: same scope, flags, defaults, lifecycle behavior, and cleanup ownership.

### 2026-05-30T09:24:00-04:00 — Architecture portability directive
- Demos target macOS arm64/amd64 and Windows amd64/arm64.
- kind node images, Calico, registry, and all demo-built/pulled images must be multi-arch (`linux/amd64` + `linux/arm64`) or built for the host architecture.
- Any amd64-only pinned image or digest is a portability bug; digest pins must be checked to distinguish multi-arch index digests from single-arch image manifests.

### 2026-05-30T09:30:00-04:00 — Shared kind+Calico cluster lifecycle
- Use one shared `container-security` kind cluster with Calico v3.32.0 for all demos; set it up once with `scripts/setup-kind-cluster.{sh,ps1}` and tear it down when finished with `scripts/teardown-kind-cluster.{sh,ps1}`.
- The shared registry is the `registry:2` container named `registry` on host port 5000, connected to the `kind` Docker network and aliased so pods can pull `localhost:5000/...`.
- `setup-kind-cluster.{sh,ps1}` writes `certs.d/<host>/hosts.toml` for **both** `localhost:5000` and `registry:5000` (both → `http://registry:5000`) so admitted pods referencing `registry:5000` can be pulled in-cluster over plain HTTP (no `ImagePullBackOff … HTTP response to HTTPS client`).
- Demo cleanup scripts must only remove demo-owned resources; the shared cluster, shared registry, and `kind` network are owned by the root teardown scripts.
- Demo 2 must keep registry-centric image delivery for signing/admission; do not replace its signed-image flow with `kind load`.
- Cluster scripts should remain arch-safe: no arch-pinned kind node image and no forced `--platform` unless intentionally building multi-arch.

## Validation & Demo Fixes

### 2026-05-30 — Nebula clean-room validation (shared kind+Calico `container-security`, k8s v1.35.0, arm64)

Real end-to-end run, no fabricated results. **Score: 2 PASS · 2 PARTIAL · 2 FAIL.**

| Demo | Owner | Result | One-line reason |
|------|-------|--------|-----------------|
| 1 – Policy Guardrails | Star-Lord | PARTIAL | Kyverno genuinely blocks root/unsigned & admits compliant, but images never reach the kind node (`ErrImagePull`); script falsely prints compliant pod "is running". |
| 2 – Supply Chain Trust | Gamora | PARTIAL | SBOM + cosign keyed sign/verify work, but pipeline dead-ends at the Trivy gate; macOS port-5000 + Kyverno `localhost:5000` resolution break admit-signed/reject-unsigned. |
| 3 – Image Hardening | Rocket | PASS | Real Trivy: CRITICAL 195→5, HIGH 1127→21, 1.42 GB→125 MB. Minor cleanup tag-mismatch bug. |
| 4 – Runtime Detection | Drax | PASS | Falco modern-eBPF custom rule fired on all 4 `/etc` trigger writes. |
| 5 – Zero-Trust Networking | Groot | FAIL | 3-tier app never starts (`runAsNonRoot` w/o numeric UID; postgres initdb perms). Calico enforcement verified good independently. |
| 6 – Observability Signals | Mantis | FAIL | OTEL collector runs, but instrumented API blocked by `runAsNonRoot` + non-numeric `USER app` → 0 spans. |

Cross-cutting root causes: (1) the numeric-UID securityContext gap (Demos 5, 6, partly 1) — see Cross-Cutting Conventions; (2) cleanup scripts referencing stale image tags so built images leak (Demos 3 & 6). Operational note: keep ≥10 GB host disk free before a validation/talk run — building all demo images is disk-heavy. Teardown via `scripts/teardown-kind-cluster.sh --force` is idempotent.

### 2026-05-30 — Nebula live RE-validation (fresh shared kind+Calico `container-security`, k8s v1.35.0, arm64, cosign v3.0.6)

Real end-to-end run (cluster built from scratch, each demo built/loaded/ran/cleaned, then torn down). **Score: 5 PASS · 1 FAIL.** The numeric-UID securityContext fix HOLDS — Demos 1, 5, 6 are now GREEN; Demos 3 & 4 re-confirmed GREEN.

| Demo | Owner | Prior | Now | One-line verdict |
|------|-------|-------|-----|------------------|
| 1 – Policy Guardrails | Star-Lord | PARTIAL | **PASS** | `kind load` works (no ErrImagePull); root & unsigned BLOCKED; compliant pod reaches Ready; success gated on real `kubectl wait`. |
| 2 – Supply Chain Trust | Gamora | PARTIAL | **FAIL** | As shipped, fail-closed-for-all + signed app crashes; 5 HIGH breaks (B1–B5) + cleanup gap (B7). Discrimination works only after manual workarounds. |
| 3 – Image Hardening | Rocket | PASS | **PASS** | Trivy CRITICAL 195→5, HIGH 1127→21, 1.42GB→125MB; cleanup removes `:before`/`:after`. |
| 4 – Runtime Detection | Drax | PASS | **PASS** | Falco modern-eBPF rule fired on all 4 `/etc` trigger writes. |
| 5 – Zero-Trust Networking | Groot | FAIL | **PASS** | frontend+api+db all roll out (api UID 65532, postgres uid 70 + PGDATA subdir); Calico deny→timeout, allow→200. |
| 6 – Observability Signals | Mantis | FAIL | **PASS** | API runs UID 65532 w/ writable /tmp; load Job completes; collector logs 22 spans / 3 ResourceSpans for `service.name=guardian-telemetry`. |

Demo 2's failures are **independent** of the UID convention — they are cosign-version (B1), AirPlay-port (B2), Kyverno HTTP-registry (B3), containerd `registry:5000` alias (B4), and distroless `sys.path` (B5) issues surfaced only by a live run against cosign 3.0.6 + current Kyverno + the HTTP registry path. New bugs B1–B8 were filed and routed to Gamora (B1–B5, B7), Rocket/cross-cutting (B6), and Drax (B8).

> Demos 1, 3, 4, 5, 6 are GREEN. Demo 2 fix pass 2 (below) is applied and locally verified; a **final live re-validation of Demo 2 admission discrimination on a fresh cluster is still REQUIRED** (cluster torn down post-run). No git commits (worktree backend).

### 2026-05-30 — Demo 2 fix pass 2 (Gamora) — B1–B5, B7
- **B1 (cosign 3.x format):** `run-pipeline.{sh,ps1}` + `pipeline/Makefile` now resolve the pushed digest and sign it with version-guarded legacy-format flags (`--use-signing-config=false --new-bundle-format=false --tlog-upload=false`; verify `--insecure-ignore-tlog=true`). Verified: cosign 3.0.6 produced a legacy `sha256-….sig` that `cosign verify` accepts (the format Kyverno reads). cosign 2.x still works (flags added only if advertised).
- **B2 (AirPlay port):** default registry `localhost:5000` → `127.0.0.1:5000` across `run-pipeline.{sh,ps1}`, `Makefile`, and README; `start_registry` matches `localhost:*` or `127.0.0.1:*`; in-cluster `registry:5000` alias intact. Verified: push/sign/verify with no 403.
- **B3 (Kyverno insecure registry):** new `setup-admission.{sh,ps1}` twin installs Kyverno if absent and **always** patches `kyverno-admission-controller` with `--allowInsecureRegistry=true` (idempotent), removing the manual patch. Live-only confirm pending.
- **B4 (containerd alias):** `setup-kind-cluster.{sh,ps1}` now writes `certs.d` for both `localhost:5000` and `registry:5000`. Live-only confirm pending.
- **B5 (distroless sys.path):** `pipeline/Dockerfile:24` COPY target → `/usr/lib/python3.11/site-packages` + `ENV PYTHONPATH=…`; numeric `USER 65532` retained. Verified: `import flask` → 3.1.3, app serves HTTP 200, syft now reports 22 python packages (was 0).
- **B7 (cleanup completeness):** `cleanup.{sh,ps1}` now delete `demo-gamora` ns + ClusterPolicy + `guardian-cosign-pub` secret and remove demo images across all three registry-host tags; never touches the shared registry/cluster.
- B1, B2, B5, B7 verified locally end-to-end; B3, B4 are correct-by-construction pending the live cluster.

### 2026-05-30 — Demo 2 focused live re-validation: FAIL (pass-2) → fix pass 3 (Gamora) → **PASS (pass-3)**

**Headline: Demo 2 reached PASS on pass-3; the full 6-demo suite is now 6/6 GREEN, all validated live on kind+Calico with zero manual intervention.**

- **Pass-2 (Nebula, focused Demo 2 only):** FAIL out-of-the-box. Two **blocking** bugs surfaced only by a live run against cosign 3.0.6 + Kyverno v1.18: (1) `setup-admission.sh` set the Kyverno Helm `extraArgs` with list-index form → `--0=…` garbage flag → admission controller **CrashLoopBackOff** (and a substring `grep` masked the safety-net patch); (2) the policy lacked `rekor.ignoreTlog`, so the `--tlog-upload=false` signature was rejected even for the SIGNED image (`signature not found in transparency log`) → no discrimination, everything rejected. Upstream B1/B2/B4/B5 were proven sound (admit/reject worked after temporary manual patches). One minor cleanup gap: `cleanup.sh` `../`-relative paths left `attestations/sbom.json` behind.
- **Fix pass 3 (Gamora):** (BUG1) Helm `--set` → map form `admissionController.container.extraArgs.allowInsecureRegistry=true`; safety-net patch → exact `jq` element match that sanitizes `--0=*`/`--allowInsecureRegistry=false` before appending the real flag; `.ps1` twin mirrored. (BUG2) added `rekor.ignoreTlog: true` under the key attestor in `policy-require-signature.yaml`. (BUG3) `cleanup.sh` now `cd`s to its project root and uses demo-root-relative paths (the `.ps1` twin already used `$PSScriptRoot`). Proven locally via `helm template` map-vs-list contrast, jq sanitize sim, YAML lint, and a foreign-CWD cleanup run. See Cross-Cutting Conventions for the two durable lessons.
- **Pass-3 (Nebula, focused Demo 2 only): ✅ PASS — ZERO manual intervention.** Live on fresh kind+Calico `container-security` (cosign v3.0.6, Kyverno v1.18.x). BUG1: admission controller **Running 1/1**, args end with real `--allowInsecureRegistry=true`, no bad-flag errors. BUG2: SIGNED image (digest `sha256:2487df02…`) **ADMITTED**, pulled `registry:5000/...` in 1.057s, **Ready**, flask `GET /` → **HTTP 200**; verify-images annotation `"…:v0.1.0-secure":"pass"`. Distinct UNSIGNED (`sha256:252af90f…`, `--no-cache` rebuild) **REJECTED** with literal `autogen-require-signed-images: 'failed to verify image registry:5000/guardian-demo-app:v0.1.0-unsigned: .attestors[0].entries[0].keys: no signatures found'`. BUG3: `cleanup.sh` from demo root removed `attestations/sbom.json` (2,063,795 B) + ns/policy/secret; shared `registry` left Up. Teardown idempotent. No regressions to B1/B2/B4/B5.
- **Result: FULL SUITE 6/6 GREEN** — Demos 1, 3, 4, 5, 6 unchanged from the prior re-validation; Demo 2 now PASSES. No remaining blockers.
- **One optional cosmetic polish (owner: Gamora, NOT required for PASS):** under `set -euo pipefail`, the unsigned `kubectl apply` returns non-zero when Kyverno blocks at Deployment-apply time, so `setup-admission.sh` step 6's own green "UNSIGNED image REJECTED" summary line doesn't print (the literal `no signatures found` webhook message is still shown; rejection is correct). Suggested fix: wrap the step-6 `kubectl apply -f manifests/deploy-unsigned.yaml` in `… || true`. A `gamora-demo2-polish.md` note covering this had NOT arrived in the inbox at merge time.

### 2026-05-30 — Demo 1 fix (Star-Lord)
- Deliver locally-built `guardian-demo:{secure,insecure}` to the node via guarded `kind load docker-image` (only when `kind` CLI + the `container-security` cluster exist; otherwise informational note for Docker Desktop fallback). Demo 1 uses UNsigned local images, so `kind load` is correct and does not conflict with Demo 2's registry-centric signed-image flow.
- Gate the "compliant pod is running" message on a real `kubectl wait --for=condition=Ready pod/nonroot-pod`; on failure print FAILURE, dump events, and `exit 1` — the success message can no longer lie.
- Fixed the line-118 integer-comparison false positive (`grep -c … || true` with `${VAR:-0}` guards). Applied across `run-demo`/`build-images` `.sh` + `.ps1` twins. `nonroot-pod.yaml` uses numeric `runAsUser: 65532`.

### 2026-05-30 — Demo 2 fix (Gamora)
- Rebased `pipeline/Dockerfile` runtime onto `gcr.io/distroless/python3-debian12` (digest-pinned multi-arch, shared with Demo 3), numeric `USER 65532`.
- Admission must use an **in-cluster-resolvable** registry name (`registry:5000/...`), NOT `localhost:5000`, which from inside the cluster resolves to Kyverno's own loopback and fails closed for everything. `hosts.toml` only affects containerd pulls, not Kyverno's Go registry client.
- `policy-require-signature.yaml`: `failureAction: Enforce`, `mutateDigest: false`, `verifyDigest: false`, `required: true`; real key injected via `publicKeys: k8s://kyverno/guardian-cosign-pub` (no private key in git); rules scoped to namespace `demo-gamora`.
- Trivy gate is now INFORMATIONAL by default (`STRICT_SCAN=1` restores hard gate) — remaining HIGH/CRITICAL are mostly unfixable base-OS CVEs. cosign sign/verify use `--allow-http-registry` (+ `--yes`).
- cosign signs the **digest, not the tag**: the unsigned case must build a genuinely DISTINCT image (different digest), not a re-tag of the signed one.
- macOS host port 5000 collides with AirPlay Receiver — documented; use `127.0.0.1:5000`/`--allow-http-registry`. Added `demo-namespace.yaml`, `deploy-signed.yaml` (EXPECT ADMITTED), `deploy-unsigned.yaml` (EXPECT REJECTED); cleanup also removes the `:v0.1.0-unsigned` image.

### 2026-05-30 — Demo 3 cleanup fix (Rocket)
- Aligned `cleanup.{sh,ps1}` to remove the tags the build actually creates: `guardian-demo:before` / `guardian-demo:after` (was the stale `:baseline` / `:hardened`), keeping `.sh`/`.ps1` parity and idempotent guards. No behavior change.

### 2026-05-30 — Exec-bit + Demo-4 cleanup fix (Rocket) — B6, B8
- **B6 (exec bits, cross-cutting):** all 22 repo `.sh` scripts were committed mode `100644`, so `run-demo.sh`'s direct `./scripts/*.sh` calls hit `Permission denied` on fresh clones. Set executable mode `100755` (20 tracked via `git update-index --chmod=+x`, plus `teardown-kind-cluster.sh` newly staged); `.ps1` untouched (no unix exec bit). No script contents changed. See Cross-Cutting Conventions.
- **B8 (Demo 4 namespace orphan):** `cleanup.{sh,ps1}` now delete the `falco` namespace unconditionally (idempotent) after uninstall, so the helm path no longer leaves an empty namespace; both twins updated in parity and "Removed resources" summary amended.

### 2026-05-30 — Demo 5 fix (Groot)
- Only `manifests/base-services.yaml` changed; all NetworkPolicies and the `8080` wiring left untouched (Calico enforcement already verified good).
- `api` (go-httpbin, distroless/base root default): `runAsNonRoot: true` + numeric `runAsUser/Group: 65532`, drop ALL caps.
- `frontend` (nginxdemos/hello, must be root to bind port 80): explicit `runAsNonRoot: false`, drop ALL caps, add only `NET_BIND_SERVICE`.
- `db` (postgres:16-**alpine** is uid/gid **70**, NOT 999): pod `fsGroup: 70`, container `runAsUser/Group: 70`; `PGDATA=/var/lib/postgresql/data/pgdata` subdir on an emptyDir so initdb owns a clean dir.

### 2026-05-30 — Demo 6 fix (Mantis)
- `app/Dockerfile`: replaced named `USER app` with numeric `USER 65532`; added `ENV HOME=/tmp` + `TMPDIR=/tmp` for `readOnlyRootFilesystem: true`.
- `instrumented-api.yaml`: added `runAsUser/Group: 65532` paired with the existing hardening; added an emptyDir `tmp` volume mounted at `/tmp`.
- `load-generator.yaml`: `restartPolicy: OnFailure`, `backoffLimit: 3`, `activeDeadlineSeconds: 240`; the Job now waits for `guardian-telemetry:8080/health` before generating load (removes the start-race that produced 0 spans).
- Cleanup tag fix: remove `guardian-telemetry:local` (what build/run creates), not the stale `ghcr.io/codebytes/guardian-telemetry:0.1.0`; `run-demo.ps1` now mirrors the `.sh` build+`kind load` flow.
- Falco↔app correlation remains by **pod/namespace/timestamp**, not shared trace IDs (per the standing Demo 6 decision).

### 2026-06-03T13:37:10.790+02:00: PowerShell demo scripts fail from README cwd
**By:** Nebula
**Context:** Clean-room Windows validation ran each PowerShell script from its demo directory, matching README examples such as `./scripts/run-demo.ps1`.
**Decision/Finding:** Demo 2 `scripts/run-pipeline.ps1` and Demo 6 `scripts/run-demo.ps1` are cwd-sensitive and should resolve paths from `$PSScriptRoot`; Demo 1 `scripts/build-images.ps1` also builds invalid `/guardian-demo:*` tags when no registry is set.
**Why:** Demo 2 changed to `../` from the demo root and Docker failed with `GetFileAttributesEx pipeline: The system cannot find the file specified`; Demo 6 failed `Push-Location ..\app` looking for `D:\container-security\demos\app`; Demo 1 generated `/guardian-demo:secure` and Docker rejected `invalid reference format`.

### 2026-06-03T13:37:10.790+02:00: Cleanup scripts mutate tracked demo artifacts
**By:** Nebula
**Context:** Clean-room validation ran demo cleanup scripts after each demo to reset state.
**Decision/Finding:** Cleanup scripts should not delete files committed to the repository, or those artifacts should be untracked/generated-only; otherwise a validation run leaves the worktree dirty.
**Why:** Demo 2 cleanup deleted tracked `demos/2-supply-chain-trust/attestations/sbom.json`. Demo 3 cleanup deleted tracked `reports/*.txt` and `demo-results.txt` while leaving JSON reports behind, producing stale/dirty report state until restored manually.

### 2026-06-03T13:37:10.790+02:00: Demo 1 uses plain local image tags by default
**By:** Star-Lord
**Context:** Demo 1's local image build broke on Windows when an empty registry produced `/guardian-demo:secure`. The demo manifests and run scripts already expect plain local tags like `guardian-demo:secure`.
**Decision:** Keep Demo 1 registry default empty and build/use plain `guardian-demo:{secure,insecure}` tags unless a registry is explicitly passed to the build script.
**Why:** This is the simplest path for Demo 1's local, unsigned image flow and stays aligned with its manifests and kind-load delivery, while Demo 2 remains the registry-centric signed-image demo.

### 2026-06-03T13:37:10.790+02:00: Demo 2 script-root paths and preflight
**By:** Gamora
**Context:** Demo 2 pipeline failed differently depending on caller CWD and continued past missing Syft/Cosign prerequisites into confusing mid-pipeline command errors.
**Decision:** Demo 2 executable scripts resolve demo-root paths from the script location, and `run-pipeline` fails fast with explicit tool/key preflight guidance before building.
**Why:** This makes README-documented invocation paths reliable on Windows/macOS/Linux and turns missing supply-chain tooling into actionable setup feedback instead of misleading path or CommandNotFound failures.

### 2026-06-03T13:37:10.790+02:00: Demo 6 requires demo 4 Falco handoff
**By:** Mantis
**Context:** Demo 6 installs Falcosidekick and the Falco-to-OTLP adapter, then configures an existing Falco Helm release to send alerts through Falcosidekick. Demo 4 is the repository convention for installing Falco into the `falco` namespace with the Helm chart.
**Decision:** Treat demo 4's Falco Helm release, namespace, and DaemonSet as required prerequisites for demo 6; fail fast with a clear "run demo 4 first" message instead of attempting a second Falco install.
**Why:** This preserves cleanup ownership, keeps Falco rule configuration centralized in demo 4, and makes the cross-demo observability handoff explicit before demo 6 builds or deploys anything.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
