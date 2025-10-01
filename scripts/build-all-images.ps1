# Container Security Demos - Docker Hub Build & Push Script (PowerShell)
# Builds and pushes all demo images to Docker Hub registry

param(
    [string]$Registry = $env:DOCKER_REGISTRY ?? "codebytes",
    [string]$Tag = $env:TAG ?? "latest",
    [string]$Version = $env:VERSION ?? "v1.0.0",
    [switch]$Help
)

# Configuration
$BuildDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$GitCommit = try { (git rev-parse --short HEAD 2>$null) } catch { "unknown" }

# Colors for output
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    White = "White"
}

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Colors.Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Colors.Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Colors.Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Colors.Red
}

# Show usage information
function Show-Usage {
    Write-Host "Container Security Demos - Docker Hub Build & Push Script" -ForegroundColor $Colors.Blue
    Write-Host ""
    Write-Host "Usage: .\build-all-images.ps1 [OPTIONS]" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor $Colors.White
    Write-Host "  -Registry REGISTRY    Docker registry (default: codebytes)" -ForegroundColor $Colors.White
    Write-Host "  -Tag TAG             Image tag (default: latest)" -ForegroundColor $Colors.White
    Write-Host "  -Version VERSION     Version tag (default: v1.0.0)" -ForegroundColor $Colors.White
    Write-Host "  -Help                Show this help message" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Host "Environment Variables:" -ForegroundColor $Colors.White
    Write-Host "  DOCKER_REGISTRY      Override default registry" -ForegroundColor $Colors.White
    Write-Host "  TAG                  Override default tag" -ForegroundColor $Colors.White
    Write-Host "  VERSION              Override default version" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor $Colors.White
    Write-Host "  .\build-all-images.ps1                                    # Build with defaults" -ForegroundColor $Colors.White
    Write-Host "  .\build-all-images.ps1 -Registry myregistry -Tag dev      # Custom registry and tag" -ForegroundColor $Colors.White
    Write-Host "  `$env:TAG='v2.0.0'; .\build-all-images.ps1               # Custom version via env var" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Host "Before running:" -ForegroundColor $Colors.White
    Write-Host "  docker login                                              # Login to Docker Hub" -ForegroundColor $Colors.White
}

if ($Help) {
    Show-Usage
    exit 0
}

# Check if Docker is available
function Test-Docker {
    if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker is not installed or not in PATH"
        exit 1
    }

    try {
        docker info | Out-Null
        Write-Success "Docker is available and running"
    }
    catch {
        Write-Error "Docker daemon is not running"
        exit 1
    }
}

# Docker login check
function Test-DockerLogin {
    Write-Info "Checking Docker Hub authentication..."
    $dockerInfo = docker info 2>$null
    if (-not ($dockerInfo -match "Username")) {
        Write-Warning "Not logged into Docker Hub. Please run: docker login"
        Write-Info "After login, re-run this script."
        $response = Read-Host "Do you want to login now? (y/n)"
        if ($response -match "^[Yy]") {
            docker login
        }
        else {
            exit 1
        }
    }
    Write-Success "Docker Hub authentication verified"
}

# Build a single image
function Build-Image {
    param(
        [string]$Dockerfile,
        [string]$ImageName,
        [string]$ContextDir
    )

    $FullImage = "${Registry}/${ImageName}:${Tag}"
    $VersionImage = "${Registry}/${ImageName}:${Version}"

    Write-Info "Building ${ImageName}..."
    Write-Info "  Dockerfile: ${Dockerfile}"
    Write-Info "  Context: ${ContextDir}"
    Write-Info "  Image: ${FullImage}"

    $buildArgs = @(
        "build"
        "--file", $Dockerfile
        "--tag", $FullImage
        "--tag", $VersionImage
        "--label", "org.opencontainers.image.title=${ImageName}"
        "--label", "org.opencontainers.image.description=Container Security Demo Image"
        "--label", "org.opencontainers.image.vendor=codebytes"
        "--label", "org.opencontainers.image.created=${BuildDate}"
        "--label", "org.opencontainers.image.revision=${GitCommit}"
        "--label", "org.opencontainers.image.version=${Version}"
        "--label", "org.opencontainers.image.source=https://github.com/codebytes/container-security"
        $ContextDir
    )

    try {
        docker @buildArgs
        Write-Success "✅ Built ${ImageName}"
        return $true
    }
    catch {
        Write-Error "❌ Failed to build ${ImageName}: $_"
        return $false
    }
}

# Push a single image
function Push-Image {
    param([string]$ImageName)

    $FullImage = "${Registry}/${ImageName}:${Tag}"
    $VersionImage = "${Registry}/${ImageName}:${Version}"

    Write-Info "Pushing ${ImageName}..."

    try {
        docker push $FullImage
        docker push $VersionImage
        Write-Success "✅ Pushed ${ImageName}"
        Write-Info "  Available at: https://hub.docker.com/r/${Registry}/${ImageName}"
        return $true
    }
    catch {
        Write-Error "❌ Failed to push ${ImageName}: $_"
        return $false
    }
}

# Build and push all images
function Build-All {
    $projectRoot = Split-Path -Parent $PSScriptRoot
    Set-Location $projectRoot

    Write-Info "🚀 Container Security Demos - Docker Hub Build & Push"
    Write-Info "=================================================="
    Write-Info "Registry: ${Registry}"
    Write-Info "Tag: ${Tag}"
    Write-Info "Version: ${Version}"
    Write-Info "Build Date: ${BuildDate}"
    Write-Info "Git Commit: ${GitCommit}"
    Write-Host ""

    $imagesBuilt = @()
    $imagesFailed = @()

    # Demo 1: Policy Guardrails Images
    Write-Info "📋 Building Demo 1: Policy Guardrails Images"
    if (Build-Image "demos/1-policy-guardrails/images/Dockerfile.secure" "guardian-demo-secure" "demos/1-policy-guardrails") {
        $imagesBuilt += "guardian-demo-secure"
    } else {
        $imagesFailed += "guardian-demo-secure"
    }

    if (Build-Image "demos/1-policy-guardrails/images/Dockerfile.insecure" "guardian-demo-insecure" "demos/1-policy-guardrails") {
        $imagesBuilt += "guardian-demo-insecure"
    } else {
        $imagesFailed += "guardian-demo-insecure"
    }

    # Demo 2: Supply Chain Trust
    Write-Info "🔒 Building Demo 2: Supply Chain Trust"
    if (Build-Image "demos/2-supply-chain-trust/pipeline/Dockerfile" "guardian-demo-app" "demos/2-supply-chain-trust") {
        $imagesBuilt += "guardian-demo-app"
    } else {
        $imagesFailed += "guardian-demo-app"
    }

    # Demo 3: Image Hardening
    Write-Info "🛡️ Building Demo 3: Image Hardening Images"
    if (Build-Image "demos/3-image-hardening/dockerfiles/Dockerfile.before" "guardian-demo-vulnerable" "demos/3-image-hardening") {
        $imagesBuilt += "guardian-demo-vulnerable"
    } else {
        $imagesFailed += "guardian-demo-vulnerable"
    }

    if (Build-Image "demos/3-image-hardening/dockerfiles/Dockerfile.after" "guardian-demo-hardened" "demos/3-image-hardening") {
        $imagesBuilt += "guardian-demo-hardened"
    } else {
        $imagesFailed += "guardian-demo-hardened"
    }

    # Demo 6: Observability Signals
    Write-Info "📊 Building Demo 6: Observability Signals"
    if (Build-Image "demos/6-observability-signals/app/Dockerfile" "guardian-telemetry" "demos/6-observability-signals/app") {
        $imagesBuilt += "guardian-telemetry"
    } else {
        $imagesFailed += "guardian-telemetry"
    }

    # Source images
    Write-Info "🏗️ Building Source Images"
    if (Build-Image "src/Dockerfile" "guardian-demo" "src") {
        $imagesBuilt += "guardian-demo"
    } else {
        $imagesFailed += "guardian-demo"
    }

    if (Build-Image "src/Dockerfile.insecure" "guardian-demo-base-insecure" "src") {
        $imagesBuilt += "guardian-demo-base-insecure"
    } else {
        $imagesFailed += "guardian-demo-base-insecure"
    }

    Write-Host ""
    Write-Info "📦 Build Summary"
    Write-Success "Successfully built: $($imagesBuilt.Count) images"
    foreach ($image in $imagesBuilt) {
        Write-Host "  ✅ $image" -ForegroundColor $Colors.Green
    }

    if ($imagesFailed.Count -gt 0) {
        Write-Error "Failed to build: $($imagesFailed.Count) images"
        foreach ($image in $imagesFailed) {
            Write-Host "  ❌ $image" -ForegroundColor $Colors.Red
        }
    }

    # Push images if builds were successful
    if ($imagesBuilt.Count -gt 0) {
        Write-Host ""
        Write-Info "🚀 Pushing images to Docker Hub..."
        $pushedCount = 0

        foreach ($image in $imagesBuilt) {
            if (Push-Image $image) {
                $pushedCount++
            }
        }

        Write-Host ""
        Write-Success "🎉 Build and Push Complete!"
        Write-Info "Pushed ${pushedCount}/$($imagesBuilt.Count) images to Docker Hub"
        Write-Info "Visit: https://hub.docker.com/u/${Registry}"
    }
    else {
        Write-Error "No images to push due to build failures"
        exit 1
    }
}

# Main execution
function Main {
    Test-Docker
    Test-DockerLogin
    Build-All
}

# Run main function
Main