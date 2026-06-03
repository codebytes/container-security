# One cluster for all 6 demos

This guide gets you a single local Kubernetes cluster that runs **all six**
container-security demos — including demo 5 (zero-trust networking), which only
*truly enforces* NetworkPolicies on a CNI that supports them.

---

## Lifecycle: set up once, tear down when finished

The whole talk uses **one shared cluster** as the single source of truth.
Individual demos **do NOT** need their own cluster setup/teardown.

1. **Setup once** — create the cluster, Calico, and the local registry:

   ```bash
   ./scripts/setup-kind-cluster.sh        # Windows: ./scripts/setup-kind-cluster.ps1
   kubectl config use-context kind-container-security
   ```

2. **Run any/all demos** against that single cluster — see the
   [demo table below](#4-run-the-demos). No per-demo cluster bootstrap required.

3. **Tear down when finished** — remove the cluster, registry, and network:

   ```bash
   ./scripts/teardown-kind-cluster.sh     # Windows: ./scripts/teardown-kind-cluster.ps1
   ```

   Deleting the kind cluster removes **all** demo workloads and namespaces in one
   shot (the nodes are containers), so you don't clean up demos individually. Both
   setup and teardown are **idempotent** and take `--force` (`-Force` in
   PowerShell) for non-interactive/CI use.

> If a per-demo README still tells you to spin up or tear down its own cluster,
> those steps are **superseded** by this shared cluster — use the lifecycle above
> instead.

---

## Supported architectures

The cluster scripts and the cluster stack run on:

- **macOS** — Apple Silicon **arm64** and Intel **amd64**
- **Windows** — **amd64** and **arm64** (PowerShell 7+)
- **Linux** — amd64 and arm64

The cluster stack is fully multi-arch: the kind **default node image** (not
arch-pinned by the script), **Calico v3.32.0** (`calico/node`, `cni`,
`kube-controllers`, `typha`), and **registry:2** all publish amd64 + arm64.

> **Caveat — demo container images.** Portability risk lives in *demo* images, not
> the scripts. A demo image pinned to an **amd64-only** tag or a **single-arch
> sha256 digest** will fail (or fall back to slow emulation) on Apple Silicon /
> Windows arm64. Known issue at time of writing: **demo 5** uses
> `kennethreitz/httpbin`, which is **amd64-only** — on arm64 hosts it may
> `crashloop`/`exec format error` inside a kind node. See the architecture audit
> in `.squad/decisions/inbox/nebula-cluster-impl.md`; a multi-arch httpbin
> substitute (e.g. `mccutchen/go-httpbin`) is recommended for arm64 parity.
> Note: digests *can* be multi-arch if they reference an image **index** — demo 3's
> digest-pinned base images were verified to be index digests (amd64+arm64), so
> they are safe.

---

## Which cluster should I use?

| | **kind + Calico** (recommended) | **Docker Desktop built-in K8s** |
|---|---|---|
| Setup effort | one script, ~2–3 min | toggle in Settings |
| **Demo 5 (NetworkPolicy)** | ✅ **truly enforced** (deny actually blocks) | ⚠️ **fails open** — policies accepted but **not enforced**; demo only *simulates* zero trust |
| Demos 1–4, 6 | ✅ all work | ✅ all work |
| Custom signed images (demo 2) | ✅ via registry wired into the kind network | ✅ images already local to the engine |
| Resource cost | extra kind containers | uses existing Docker Desktop VM |
| Cleanup | `kind delete cluster --name container-security` | disable Kubernetes in Settings |

**Recommendation:** run everything on **kind + Calico**. It's the only setup
where demo 5 genuinely enforces zero-trust, and it handles all other demos.
Keep Docker Desktop's built-in Kubernetes as a convenient fallback for demos
1–4 and 6 — but if you show demo 5 there, say explicitly that it's **simulation
mode** (the demo's `run-demo.sh` already prints this warning). Never claim
enforcement on the built-in CNI.

---

## Prerequisites

- **Docker Desktop 4.51+** (macOS/Windows) or Docker Engine (Linux).
- **kind ≥ v0.27.0** — `brew install kind` (macOS) or see
  [kind install docs](https://kind.sigs.k8s.io/docs/user/quick-start/#installation).
- **kubectl** — [install docs](https://kubernetes.io/docs/tasks/tools/).
- **Calico v3.32.0** — installed automatically by the setup script (pinned).
- For demo 2: `syft`, `trivy`, `cosign`.

> **Docker Desktop containerd image store:** the setup script uses the
> standalone `kind` CLI, which works regardless of image store. If you instead
> use Docker Desktop's **built-in kind provisioner**, you must enable the
> containerd image store (**Settings → General → "Use containerd for pulling and
> storing images"**, Docker Desktop 4.51+).

---

## Quickstart

### 1. Create the cluster (kind + Calico + local registry)

macOS / Linux:

```bash
./scripts/setup-kind-cluster.sh          # add --force to skip the recreate prompt (CI)
```

Windows (PowerShell):

```powershell
./scripts/setup-kind-cluster.ps1         # add -Force to skip the recreate prompt (CI)
```

This creates the `container-security` cluster with Calico for NetworkPolicy
enforcement, and starts/wires a local registry on **`localhost:5000`** into the
`kind` Docker network — so images pushed to `localhost:5000` are reachable from
both your host **and** the cluster nodes (required for demo 2's signed-image
admission).

### 2. Point kubectl at the cluster

```bash
kubectl config use-context kind-container-security
```

Switch back to Docker Desktop anytime with
`kubectl config use-context docker-desktop`.

### 3. Build + push demo images to the local registry

Build with the helper script, then tag/push to `localhost:5000`:

```bash
./scripts/build-demo.sh 2
docker tag codebytes/guardian-demo-app:latest localhost:5000/guardian-demo-app:v0.1.0-secure
docker push localhost:5000/guardian-demo-app:v0.1.0-secure
```

Demo 2's pipeline (`demos/2-supply-chain-trust/scripts/run-pipeline.sh`)
**detects and reuses** this kind-network registry automatically, so its
cosign-signed image is verifiable at admission. If you run the pipeline without
first creating the cluster, it falls back to a standalone registry and warns
that images won't pull from a kind cluster.

### 4. Run the demos

| Demo | Path | Notes |
|------|------|-------|
| 1 – Policy Guardrails (Star-Lord) | [`demos/1-policy-guardrails/`](../demos/1-policy-guardrails/) | Kyverno admission policies |
| 2 – Supply Chain Trust (Gamora) | [`demos/2-supply-chain-trust/`](../demos/2-supply-chain-trust/) | SBOM, scan, **sign**, verify at admission — needs the local registry |
| 3 – Image Hardening (Rocket) | [`demos/3-image-hardening/`](../demos/3-image-hardening/) | Trivy before/after |
| 4 – Runtime Detection (Drax) | [`demos/4-runtime-detection/`](../demos/4-runtime-detection/) | Falco custom rule |
| 5 – Zero-Trust Networking (Groot) | [`demos/5-zero-trust-networking/`](../demos/5-zero-trust-networking/) | **Requires Calico** — enforced on this cluster |
| 6 – Observability Signals (Mantis) | [`demos/6-observability-signals/`](../demos/6-observability-signals/) | OTEL + Falco correlation |

### 5. Clean up

Tear down the whole shared environment when the talk is finished:

```bash
./scripts/teardown-kind-cluster.sh       # Windows: ./scripts/teardown-kind-cluster.ps1
```

This deletes the cluster (and all demo workloads), removes the local registry,
and cleans up the `kind` network. Equivalent manual command:

```bash
kind delete cluster --name container-security
```

---

## How the local registry wiring works

The setup script follows the official
[kind local-registry pattern](https://kind.sigs.k8s.io/docs/user/local-registry/):

1. Runs a `registry:2` container named `registry` on host port **5000**.
2. Connects it to the `kind` Docker network so nodes can reach it as
   `registry:5000`.
3. Writes a containerd `certs.d/localhost:5000/hosts.toml` alias on each node so
   that `localhost:5000` (what you push to, and what manifests/Kyverno
   reference) resolves to the in-network registry.
4. Publishes the `local-registry-hosting` ConfigMap (KEP-1755).

This keeps demo 2's image refs (`localhost:5000/guardian-demo-app`), cosign keyed
signatures, and Kyverno `verifyImages` configuration **unchanged** while making
those signed images pullable — and verifiable — inside the Calico cluster.

> **Why not `kind load docker-image`?** It loads an image into the nodes' local
> containerd by tag, bypassing the registry. Cosign signatures live in the
> registry (addressed by digest), so admission-time verification (Kyverno
> `verifyImages` / `cosign verify`) can't resolve them. Use the registry pattern
> above for any signed image.

---

## References

- [Calico — Installing on Kind](https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind)
- [Calico releases](https://github.com/projectcalico/calico/releases)
- [kind — Local Registry](https://kind.sigs.k8s.io/docs/user/local-registry/)
- [Docker Desktop — Kubernetes](https://docs.docker.com/desktop/features/kubernetes/)
