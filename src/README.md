# Guardian Demo Application

A simple Python web server for demonstrating container security policies.

## Features

- **Health Check Endpoint**: `/health` returns JSON status
- **Web Interface**: `/` shows security status with visual indicators
- **Security Reporting**: Shows current user ID and root access status
- **Container-Ready**: Designed for Kubernetes deployment

## Security Implementations

### Secure Version (`Dockerfile`)
- ✅ Non-root user (`guardian` UID 1000+)
- ✅ Minimal base image (python:3.11-slim)
- ✅ Proper file permissions
- ✅ Health check configuration
- ✅ Security labels

### Insecure Version (`Dockerfile.insecure`)
- ❌ Runs as root (UID 0)
- ❌ No user restrictions
- ❌ Demonstrates policy violations

## Building Images

### Secure Image
```bash
docker build -t guardian-demo:secure .
```

### Insecure Image
```bash
docker build -f Dockerfile.insecure -t guardian-demo:insecure .
```

## Running Locally

```bash
# Secure version
docker run -p 8080:8080 guardian-demo:secure

# Insecure version
docker run -p 8080:8080 guardian-demo:insecure
```

Then visit:
- http://localhost:8080 - Web interface
- http://localhost:8080/health - Health check JSON

## Expected Behavior

| Version | User ID | Root Access | Kyverno Policy |
|---------|---------|-------------|----------------|
| Secure  | 1000+   | Disabled    | ✅ Allowed     |
| Insecure| 0       | Enabled     | ❌ Blocked     |

## Container Registry

This demo is designed to work with:
- Docker Hub: `username/guardian-demo:tag`
- GitHub Packages: `ghcr.io/username/guardian-demo:tag`

## Integration with Demos

This application is used by:
- `demos/1-policy-guardrails/` - Kyverno admission control
- `demos/2-supply-chain-trust/` - Image signing and SBOM
- `demos/3-image-hardening/` - Vulnerability scanning comparisons