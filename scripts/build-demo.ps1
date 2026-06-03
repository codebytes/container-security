#requires -Version 7.0
# Individual Demo Builder for Docker Hub (PowerShell twin of build-demo.sh)
# Usage: ./build-demo.ps1 <demo_number> [tag]

param(
    [Parameter(Position = 0)]
    [string]$DemoNumber,

    [Parameter(Position = 1)]
    [string]$Tag = "latest",

    [string]$Registry = ($env:DOCKER_REGISTRY ?? "codebytes")
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    Write-Host "Usage: ./build-demo.ps1 <demo_number> [tag]"
    Write-Host ""
    Write-Host "Available demos:"
    Write-Host "  1 - Policy Guardrails (builds secure and insecure images)"
    Write-Host "  2 - Supply Chain Trust"
    Write-Host "  3 - Image Hardening (builds vulnerable and hardened images)"
    Write-Host "  6 - Observability Signals"
    Write-Host "  src - Source images"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  ./build-demo.ps1 2                    # Build demo 2 with latest tag"
    Write-Host "  ./build-demo.ps1 3 v1.0.0            # Build demo 3 with v1.0.0 tag"
    Write-Host "  `$env:DOCKER_REGISTRY='myorg'; ./build-demo.ps1 2   # Use custom registry"
}

if ([string]::IsNullOrEmpty($DemoNumber)) {
    Show-Usage
    exit 1
}

# Get project root (parent of this script's directory) and switch to it
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $ProjectRoot

Write-Host "🚀 Building Demo $DemoNumber for Docker Hub"
Write-Host "Registry: $Registry"
Write-Host "Tag: $Tag"
Write-Host ""

switch ($DemoNumber) {
    "1" {
        Write-Host "📋 Building Demo 1: Policy Guardrails"
        docker build -f demos/1-policy-guardrails/images/Dockerfile.secure `
            -t "$Registry/guardian-demo-secure:$Tag" `
            demos/1-policy-guardrails
        docker build -f demos/1-policy-guardrails/images/Dockerfile.insecure `
            -t "$Registry/guardian-demo-insecure:$Tag" `
            demos/1-policy-guardrails
        Write-Host "✅ Built: guardian-demo-secure:$Tag and guardian-demo-insecure:$Tag"
    }
    "2" {
        Write-Host "🔒 Building Demo 2: Supply Chain Trust"
        docker build -f demos/2-supply-chain-trust/pipeline/Dockerfile `
            -t "$Registry/guardian-demo-app:$Tag" `
            demos/2-supply-chain-trust
        Write-Host "✅ Built: guardian-demo-app:$Tag"
    }
    "3" {
        Write-Host "🛡️ Building Demo 3: Image Hardening"
        docker build -f demos/3-image-hardening/dockerfiles/Dockerfile.before `
            -t "$Registry/guardian-demo-vulnerable:$Tag" `
            demos/3-image-hardening
        docker build -f demos/3-image-hardening/dockerfiles/Dockerfile.after `
            -t "$Registry/guardian-demo-hardened:$Tag" `
            demos/3-image-hardening
        Write-Host "✅ Built: guardian-demo-vulnerable:$Tag and guardian-demo-hardened:$Tag"
    }
    "6" {
        Write-Host "📊 Building Demo 6: Observability Signals"
        docker build -f demos/6-observability-signals/app/Dockerfile `
            -t "$Registry/guardian-telemetry:$Tag" `
            demos/6-observability-signals/app
        Write-Host "✅ Built: guardian-telemetry:$Tag"
    }
    "src" {
        Write-Host "🏗️ Building Source Images"
        docker build -f src/Dockerfile `
            -t "$Registry/guardian-demo:$Tag" `
            src
        docker build -f src/Dockerfile.insecure `
            -t "$Registry/guardian-demo-base-insecure:$Tag" `
            src
        Write-Host "✅ Built: guardian-demo:$Tag and guardian-demo-base-insecure:$Tag"
    }
    default {
        Write-Host "❌ Unknown demo number: $DemoNumber" -ForegroundColor Red
        Write-Host "Available: 1, 2, 3, 6, src"
        exit 1
    }
}

Write-Host ""
Write-Host "🎉 Build complete! To push to Docker Hub:"
Write-Host "  docker push $Registry/[image-name]:$Tag"
Write-Host ""
Write-Host "Or use the push script:"
Write-Host "  ./scripts/push-demo.ps1 $DemoNumber $Tag"
