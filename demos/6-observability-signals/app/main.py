import logging
import random
import time
import os
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
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

tracer_provider = TracerProvider(resource=resource)
otlp_exporter = OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    insecure=True
)
tracer_provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
trace.set_tracer_provider(tracer_provider)

logger.info("OpenTelemetry configured with endpoint: %s", os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"))

app = FastAPI(title="Guardian Telemetry Demo")
FastAPIInstrumentor.instrument_app(app)
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
