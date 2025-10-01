# Building Demo Images (Local Only)

This guide explains how to build the container images needed for the Policy Guardrails Demo. **All images are built and used locally** - no external registries required.

## 🎯 Overview

The demo uses two container images to demonstrate security policies:

| Image | Purpose | Security Context |
|-------|---------|------------------|
| `guardian-demo:secure` | ✅ **Secure Example** | Non-root user (UID 1001), minimal packages |
| `guardian-demo:insecure` | ❌ **Insecure Example** | Root user (UID 0), excessive privileges |

## 🔨 Quick Start

### Build and Use Locally
```bash
# Build both images locally
./scripts/build-images.sh

# Then run the demo with local images
./scripts/run-demo.sh

# PowerShell version
.\scripts\build-images.ps1
.\scripts\run-demo.ps1
```

## 📋 Prerequisites

- **Docker** installed and running
- **Git** (for cloning repository)
- **No external registry access required**

## 🛠️ Build Scripts

### Bash Script (`build-images.sh`)

**Basic Usage:**
```bash
./scripts/build-images.sh
```

**Examples:**
```bash
# Build locally (recommended)
./scripts/build-images.sh

# Build with custom name
./scripts/build-images.sh --image-name my-guardian-demo
```

### PowerShell Script (`build-images.ps1`)

**Basic Usage:**
```powershell
.\scripts\build-images.ps1
```

**Examples:**
```powershell
# Build locally (recommended)
.\scripts\build-images.ps1

# Build with custom name
.\scripts\build-images.ps1 -ImageName "my-guardian-demo"
```

## 🔍 Testing Images

### Quick Test
```bash
# Test secure image (should show non-root user)
docker run --rm guardian-demo:secure

# Test insecure image (should show root user)
docker run --rm guardian-demo:insecure
```

## 📚 Usage After Building

```bash
# Run the demo
./scripts/run-demo.sh

# Test individual images
docker run --rm guardian-demo:secure
docker run --rm guardian-demo:insecure
```
