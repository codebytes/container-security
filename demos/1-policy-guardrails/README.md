# Policy Guardrails Demo

This demo showcases Kubernetes admission control using Kyverno policies to enforce container security best practices. It demonstrates how to prevent deployment of insecure containers while maintaining a smooth developer experience.

## 🎯 What This Demo Shows

- **Admission Control**: Block insecure pods before they can be scheduled
- **Non-Root Enforcement**: Prevent containers from running as root (UID 0) 
- **Image Security**: Simulate signed image requirements (using image tags)
- **Policy as Code**: Version-controlled security policies with clear violation messages
- **Graceful Enforcement**: Existing workloads continue while new deployments are secured

## 🚀 Demo Versions

### Interactive Demo (Recommended for Presentations)
Shows "before and after" policy enforcement with pause points for explanation:

```bash
# Linux/macOS/WSL - Interactive mode (uses local images)
./scripts/run-demo.sh

# Automated mode (no user interaction)  
./scripts/run-demo.sh --automated

# Windows PowerShell  
.\scripts\run-demo.ps1

# PowerShell - Automated mode
.\scripts\run-demo.ps1 -Automated
```

**Features:**
- Deploy insecure pods WITHOUT policies (shows the problem)
- Apply security policies (shows the solution)
- Demonstrate policy enforcement (shows protection in action)
- Interactive pauses for audience questions and exploration
- **Automated mode** for CI/CD testing and quick demos
- **Help system** with usage examples
- **Completely local** - no external registry dependencies

**Compatibility:** 
- ✅ Bash 4.0+ (Linux/macOS/WSL) 
- ✅ PowerShell 7+ (Windows/Linux/macOS)
- ✅ **All images built and used locally**

See [INTERACTIVE-DEMO.md](INTERACTIVE-DEMO.md) for detailed presentation guide.

## 📋 Prerequisites

- Kubernetes cluster (local or cloud)
- kubectl configured and connected
- helm installed (recommended for Kyverno installation)
- **Bash 4.0+** (Linux/macOS/WSL) or **PowerShell 7+** (Windows)
- **Docker** (for building images locally)

### Shell Compatibility
✅ **Tested and working with:**
- Bash 4.0+ on Linux distributions
- Bash 5.x on macOS (via Homebrew)
- WSL/WSL2 Bash on Windows
- PowerShell 7+ on Windows/Linux/macOS

### Container Images
The demo requires specific container images. **All images are built and used locally.**

**Build Images Locally:**
```bash
# Build both demo images locally
./scripts/build-images.sh

# Then run the demo (uses local images)
./scripts/run-demo.sh
```

**No external registries required** - everything runs locally for security and simplicity.

See [BUILD-IMAGES.md](BUILD-IMAGES.md) for detailed image building instructions.

## 🔧 Quick Setup

1. **Navigate to demo directory**:
   ```bash
   cd demos/1-policy-guardrails
   ```

2. **Build the demo images locally**:
   ```bash
   ./scripts/build-images.sh
   ```

3. **Run the interactive demo**:
   ```bash
   ./scripts/run-demo.sh
   ```

4. **Follow the on-screen prompts** and pause points for presentation

5. **Clean up when done**:
   ```bash
   ./scripts/cleanup.sh
   ```

## 🎬 Demo Flow Summary

1. **Clean Environment**: Remove any leftover policies/resources from previous runs
2. **Before Policies**: Deploy insecure pods (they succeed - showing the problem)
3. **Apply Policies**: Install Kyverno admission control policies  
4. **Test Enforcement**: Try insecure deployments (they get blocked)
5. **Validate Compliance**: Show compliant pods still work

## 🧹 Cleanup

```bash
./scripts/cleanup.sh
```

## 📚 Additional Resources

- [INTERACTIVE-DEMO.md](INTERACTIVE-DEMO.md) - Detailed presentation guide
- [Kyverno Documentation](https://kyverno.io/docs/)
- [Kubernetes Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
