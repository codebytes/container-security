# syntax=docker/dockerfile:1.6

FROM python:3.11-slim AS base
WORKDIR /app
COPY app/requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip setuptools>=78.1.1
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./

# Use python:3.11-slim as final stage for compatibility
FROM python:3.11-slim
WORKDIR /app
RUN groupadd -r appuser && useradd -r -g appuser appuser
# Upgrade setuptools in the final stage too
RUN pip install --no-cache-dir --upgrade pip setuptools>=78.1.1
COPY --from=base /usr/local /usr/local
COPY --from=base /app /app
USER appuser
EXPOSE 8080
ENTRYPOINT ["python", "/app/main.py"]
