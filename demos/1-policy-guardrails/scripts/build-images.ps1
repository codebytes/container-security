#requires -Version 7.0
<#
.SYNOPSIS
    Build demo images for Policy Guardrails Demo

.PARAMETER Registry
    Container registry (default: codebytes)

.PARAMETER ImageName
    Image name (default: guardian-demo)

.PARAMETER Push
    Push images to registry after building

.PARAMETER Platform
    Target platforms (default: linux/amd64,linux/arm64)

.PARAMETER Help
    Show help information

.EXAMPLE
    .\build-images.ps1
    .\build-images.ps1 -Push
    .\build-images.ps1 -Registry "local-registry" -Push
#>

param(
    [string]$Registry = ($env:REGISTRY ?? ""),
    [string]$ImageName = ($env:IMAGE_NAME ?? "guardian-demo"),
    [switch]$Push = ($env:PUSH_TO_REGISTRY -eq "true"),
    [string]$Platform = ($env:BUILD_PLATFORM ?? "linux/amd64,linux/arm64"),
    [switch]$Help
)

# Show help if requested
if ($Help) {
    Write-Host "Build demo images for Policy Guardrails Demo"
    Write-Host ""
    Write-Host "Usage: .\build-images.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -Registry <string>      Container registry (default: local only)"
    Write-Host "  -ImageName <string>     Image name (default: guardian-demo)"
    Write-Host "  -Push                   Push images to registry after building"
    Write-Host "  -Platform <string>      Target platforms (default: linux/amd64,linux/arm64)"
    Write-Host "  -Help                   Show this help message"
    Write-Host ""
    Write-Host "Environment Variables:"
    Write-Host "  `$env:REGISTRY          Container registry"
    Write-Host "  `$env:IMAGE_NAME        Image name"
    Write-Host "  `$env:PUSH_TO_REGISTRY  Set to 'true' to push images"
    Write-Host "  `$env:BUILD_PLATFORM    Target build platforms"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\build-images.ps1                                      # Build locally only"
    Write-Host "  .\build-images.ps1 -Push                                # Build and push to default registry"
    Write-Host "  .\build-images.ps1 -Registry 'local' -Push     # Build and push to custom registry"
    Write-Host "  `$env:REGISTRY='localhost:5000'; .\build-images.ps1      # Build for local registry"
    Write-Host ""
    exit 0
}

# Derived variables
$SecureTag = "$Registry/$ImageName`:secure"
$InsecureTag = "$Registry/$ImageName`:insecure"

Write-Host "🔨 Building Policy Guardrails Demo Images" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Registry: $Registry"
Write-Host "Image name: $ImageName"  
Write-Host "Push to registry: $Push"
Write-Host "Build platforms: $Platform"
Write-Host ""

# Check if Docker is available
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker is not installed or not available" -ForegroundColor Red
    exit 1
}

# Check if Docker is running
try {
    docker info | Out-Null
} catch {
    Write-Host "❌ Docker daemon is not running" -ForegroundColor Red
    exit 1
}

# Navigate to the correct directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DemoDir = Split-Path -Parent $ScriptDir
Set-Location $DemoDir

Write-Host "[1/4] Preparing build context" -ForegroundColor Cyan
# Create images directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "images" | Out-Null

# Verify Dockerfiles exist
if (-not (Test-Path "images/Dockerfile.secure") -or -not (Test-Path "images/Dockerfile.insecure")) {
    Write-Host "❌ Dockerfile.secure or Dockerfile.insecure not found in images/ directory" -ForegroundColor Red
    exit 1
}

Write-Host "[2/4] Building secure image" -ForegroundColor Cyan
Write-Host "Building: $SecureTag"
if ($Push) {
    # Build multi-platform and push
    docker buildx build `
        --platform $Platform `
        --tag $SecureTag `
        --file images/Dockerfile.secure `
        --push `
        .
} else {
    # Build for local use
    docker build `
        --tag $SecureTag `
        --file images/Dockerfile.secure `
        .
}
Write-Host "✅ Secure image built successfully" -ForegroundColor Green

Write-Host "[3/4] Building insecure image" -ForegroundColor Cyan
Write-Host "Building: $InsecureTag"
if ($Push) {
    # Build multi-platform and push
    docker buildx build `
        --platform $Platform `
        --tag $InsecureTag `
        --file images/Dockerfile.insecure `
        --push `
        .
} else {
    # Build for local use
    docker build `
        --tag $InsecureTag `
        --file images/Dockerfile.insecure `
        .
}
Write-Host "✅ Insecure image built successfully" -ForegroundColor Green

Write-Host "[4/4] Verification" -ForegroundColor Cyan
Write-Host "Listing built images:"
docker images | Select-String $ImageName

Write-Host ""
Write-Host "✅ Image build completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Built images:"
Write-Host "  Secure:   $SecureTag"
Write-Host "  Insecure: $InsecureTag"
Write-Host ""

if ($Push) {
    Write-Host "📤 Images pushed to registry: $Registry" -ForegroundColor Green
    Write-Host ""
    Write-Host "To use these images in the demo:"
    Write-Host "  .\scripts\run-demo-interactive.ps1 -Image '$Registry/$ImageName'"
} else {
    Write-Host "💡 Images built locally only (not pushed to registry)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To push images to registry:"
    Write-Host "  .\build-images.ps1 -Push"
    Write-Host ""
    Write-Host "To use local images in the demo:"
    Write-Host "  .\scripts\run-demo-interactive.ps1 -Image '$ImageName'"
}

Write-Host ""
Write-Host "🔍 To inspect the images:"
Write-Host "  docker run --rm -it $SecureTag"
Write-Host "  docker run --rm -it $InsecureTag"