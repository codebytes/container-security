# Observability Signals Demo (Mantis)

## Purpose
Connect application telemetry (OpenTelemetry), runtime security alerts (Falco), and network events (Kubernetes NetworkPolicy) into a single correlated view to shorten detection-to-response time.

## Outcomes
- Deploy an instrumented demo API emitting traces/metrics/logs via OpenTelemetry.
- Run an OpenTelemetry Collector that exports data to Prometheus and Loki-compatible outputs.
- Forward Falco alerts into the same pipeline via Falcosidekick HTTP sink.
- Visualize correlated events (trace spans referencing Falco alert ID, logs showing blocked network attempt).

## Prerequisites
- Kubernetes cluster with `kubectl` access.
- `helm` 3.x.
- `docker` or `nerdctl` (for optional local builds).
- Falco demo (from `demos/runtime-detection`) installed or re-run for alert generation.
- Prometheus & Loki stack (e.g., Grafana Agent / kube-prom-stack). For lightweight demo, we leverage `grafana/agent` Helm chart.

## Environment Variables
```powershell
$env:OTEL_NAMESPACE = "demo-mantis"
$env:IMAGE_TAG = "ghcr.io/codebytes/guardian-telemetry:0.1.0"
```

## Demo Flow
1. **Deploy Observability Stack**
   - Apply OpenTelemetry Collector deployment (`collector/otel-collector.yaml`) into namespace `demo-mantis`.
   - Collector exposes OTLP gRPC/HTTP and Prometheus scrape endpoint (port 9464).
   - Optional: Wire collector exporters to Loki/Tempo by editing ConfigMap (defaults to logging + Prometheus only).
2. **Deploy Instrumented API**
   - Build/push image (`app/Dockerfile`) or set repo digest; update `manifests/instrumented-api.yaml` if needed.
   - Apply manifest so pods export OTLP spans/metrics/logs to collector.
3. **Connect Falco Alerts**
   - Install Falcosidekick (reuse runtime demo cluster) using `manifests/falcosidekick-config.yaml` values to POST alerts → OTEL collector (logs pipeline).
4. **Trigger Events**
   - Run load job (`manifests/load-generator.yaml`) to produce standard traces/metrics.
   - Trigger Falco rule (from runtime demo) to create security alert referencing namespace/pod.
   - Optional: Temporarily deny API egress to create network-related logs.
5. **Visualize Correlation**
   - Import Grafana dashboard JSON (`dashboards/observability.json`) and map datasources.
   - If Loki/Tempo not configured, rely on collector log output (`kubectl logs deployment/otel-collector`) and Prometheus port-forward for validation.
6. **Cleanup**
   - Delete namespace, collector, Grafana Agent.

## File Structure
| Path | Description |
|------|-------------|
| `app/` | Instrumented FastAPI service emitting OTEL data |
| `collector/otel-collector.yaml` | OTEL Collector deployment/config (logging + Prometheus exporters) |
| `manifests/instrumented-api.yaml` | Deployment & Service for API |
| `manifests/falcosidekick-config.yaml` | Falcosidekick values override pointing to OTEL collector |
| `manifests/load-generator.yaml` | Busybox or k6 job hitting API |
| `dashboards/observability.json` | Grafana dashboard (requires mapped datasources) |
| `scripts/run-demo.ps1` | Automates setup, triggers events, and prints links |

## Verification Checklist
- [ ] OTEL Collector pods running and receiving spans.
- [ ] Instrumented API generating traces for `/hello` endpoint.
- [ ] Falco alert ingested and visible via Grafana Agent log pipeline.
- [ ] Dashboard displays timeline with correlated trace/span + Falco alert metadata.

## Cleanup
```powershell
kubectl delete namespace $env:OTEL_NAMESPACE --ignore-not-found
```

## Next Steps
- Wire collector to Loki/Tempo or Grafana Cloud and update dashboard datasource UIDs.
- Add OpenTelemetry metrics (histograms) for API latency vs. Falco alerts frequency.
- Automate Slack notifications using Grafana Alerting.
