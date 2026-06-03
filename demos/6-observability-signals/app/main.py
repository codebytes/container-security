import logging
import random
import time
import os
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry._logs import set_logger_provider
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("guardian.telemetry")

# Initialize OpenTelemetry tracer with OTLP exporter
resource = Resource.create(attributes={
    "service.name": os.getenv("OTEL_SERVICE_NAME", "guardian-telemetry"),
    "guardian.layer": "observability"
})

otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317")

# --- Traces ---
tracer_provider = TracerProvider(resource=resource)
tracer_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=otlp_endpoint, insecure=True))
)
trace.set_tracer_provider(tracer_provider)

# --- Metrics ---
# Wires a real MeterProvider so FastAPIInstrumentor emits the
# http.server.duration histogram the dashboard queries.
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=otlp_endpoint, insecure=True)
)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)

# --- Logs ---
logger_provider = LoggerProvider(resource=resource)
logger_provider.add_log_record_processor(
    BatchLogRecordProcessor(OTLPLogExporter(endpoint=otlp_endpoint, insecure=True))
)
set_logger_provider(logger_provider)
# Bridge stdlib logging into the OTLP logs pipeline.
logging.getLogger().addHandler(
    LoggingHandler(level=logging.INFO, logger_provider=logger_provider)
)

logger.info("OpenTelemetry configured (traces+metrics+logs) endpoint: %s", otlp_endpoint)

app = FastAPI(title="Guardian Telemetry Demo")
FastAPIInstrumentor.instrument_app(
    app, tracer_provider=tracer_provider, meter_provider=meter_provider
)
RequestsInstrumentor().instrument()
LoggingInstrumentor().instrument(set_logging_format=True)

tracer = trace.get_tracer(__name__)

@app.middleware("http")
async def add_correlation_header(request: Request, call_next):
    response = await call_next(request)
    current_span = trace.get_current_span()
    trace_id = format(current_span.get_span_context().trace_id, "032x")
    response.headers["X-Trace-Id"] = trace_id
    return response

@app.get("/health")
def health() -> JSONResponse:
    return JSONResponse({"status": "ok"})

@app.get("/hello")
def hello():
    with tracer.start_as_current_span("hello-handler") as span:
        delay_ms = random.randint(10, 200)
        span.set_attribute("guardian.delay_ms", delay_ms)
        time.sleep(delay_ms / 1000)
        logger.info("Handled /hello with delay %sms", delay_ms)
        return {"message": "Telemetry engaged", "delay_ms": delay_ms}

@app.get("/simulate-anomaly")
def simulate_anomaly():
    with tracer.start_as_current_span("simulate-anomaly") as span:
        span.set_attribute("guardian.anomaly", True)
        logger.warning("Anomaly endpoint invoked: simulate Falco alert correlation")
        return {"status": "anomaly-triggered"}
