# Guardian Demo Application Dockerfile
# This creates a minimal, secure container image

FROM python:3.11-slim

# Create non-root user for security
RUN groupadd -r guardian && useradd -r -g guardian guardian

# Set working directory
WORKDIR /app

# Copy application code
COPY app.py .

# Set appropriate permissions
RUN chown -R guardian:guardian /app

# Switch to non-root user
USER guardian

# Expose port
EXPOSE 8080

# Add labels for better container management
LABEL maintainer="Guardians of the Container Galaxy"
LABEL org.opencontainers.image.title="Guardian Demo App"
LABEL org.opencontainers.image.description="Demo application for container security policies"
LABEL org.opencontainers.image.version="1.0.0"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"

# Run the application
CMD ["python", "app.py"]