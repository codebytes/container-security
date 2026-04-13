# syntax=docker/dockerfile:1.6
FROM python:3.11-slim
WORKDIR /app
ENV PIP_NO_CACHE_DIR=1
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . ./

RUN addgroup --system app && adduser --system --ingroup app app
USER app

EXPOSE 8080
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
ENV OTEL_SERVICE_NAME=guardian-telemetry
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
