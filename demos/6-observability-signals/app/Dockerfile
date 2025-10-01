# syntax=docker/dockerfile:1.6
FROM python:3.11-slim
WORKDIR /app
ENV PIP_NO_CACHE_DIR=1
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . ./
EXPOSE 8080
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
ENV OTEL_SERVICE_NAME=guardian-telemetry
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
