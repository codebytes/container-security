# Image Hardening Demo Scripts

This directory contains platform-specific scripts for running the image hardening demonstration.

## Available Scripts

### 🐧 Linux/macOS (Bash)
**File**: `run-demo.sh`
```bash
# Make executable (if needed)
chmod +x scripts/run-demo.sh

# Run the demo
./scripts/run-demo.sh
```

### 🪟 Windows (PowerShell)
**File**: `run-demo.ps1`
```powershell
# Run the demo
./scripts/run-demo.ps1
```

## Script Features

Both scripts provide identical functionality:

### ✅ **Core Features**
- **Automated Build**: Builds both baseline and hardened images
- **Vulnerability Scanning**: Uses Trivy when available, falls back to simulated data
- **Size Comparison**: Shows dramatic size reduction (typically 80%+ improvement)
- **Security Analysis**: Compares vulnerability counts and percentages
- **Progress Indicators**: Color-coded output with emojis and status updates
- **Error Handling**: Graceful failure handling with clear error messages
- **Comprehensive Reporting**: Generates detailed results report

### 📊 **Output Includes**
- Step-by-step build progress
- Image size comparison (Before vs After)
- Vulnerability count analysis (CRITICAL/HIGH CVEs)
- Security improvement percentages
- Comprehensive results report saved to `reports/demo-results.txt`

### 🔧 **Requirements**
- **Docker**: Required for building images
- **Trivy**: Optional - scripts work with or without it
- **Internet**: Required for downloading base images

### 🎯 **Expected Results**
- **Size Reduction**: ~87% smaller (1.4GB → 180MB)
- **Vulnerability Reduction**: Significant reduction in HIGH/CRITICAL CVEs
- **Security Improvements**: Non-root user, distroless base, minimal attack surface

## Legacy Scripts

- `compare-vulns.ps1`: Legacy PowerShell script (replaced by `run-demo.ps1`)

## Usage Examples

### Quick Start (Linux/macOS)
```bash
cd /path/to/image-hardening
./scripts/run-demo.sh
```

### Quick Start (Windows)
```powershell
cd C:\path\to\image-hardening
.\scripts\run-demo.ps1
```

### Manual Steps (if scripts fail)
```bash
# Build images manually
docker build -f dockerfiles/Dockerfile.before -t guardian-demo:before .
docker build -f dockerfiles/Dockerfile.after -t guardian-demo:after .

# Compare sizes
docker images guardian-demo

# Optional: Scan with Trivy
trivy image guardian-demo:before
trivy image guardian-demo:after
```

## Troubleshooting

### Script Won't Execute (Linux/macOS)
```bash
# Fix line endings
sed -i 's/\r$//' scripts/run-demo.sh

# Ensure executable
chmod +x scripts/run-demo.sh
```

### PowerShell Execution Policy (Windows)
```powershell
# If execution is blocked
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Docker Issues
- Ensure Docker is running
- Check internet connectivity for base image downloads
- Verify sufficient disk space (~2GB for demo)

## Output Location

All results are saved to:
- `reports/before.txt` - Baseline image scan results
- `reports/after.txt` - Hardened image scan results
- `reports/demo-results.txt` - Comprehensive demo report

---

*"Ain't nothing like a good, secure container!" - Rocket 🦝*