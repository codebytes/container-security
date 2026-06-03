#requires -Version 7.0
# Push Individual Demo Images to Docker Hub (PowerShell twin of push-demo.sh)
# Usage: ./push-demo.ps1 <demo_number> [tag]

param(
    [Parameter(Position = 0)]
    [string]$DemoNumber,

    [Parameter(Position = 1)]
    [string]$Tag = "latest",

    [string]$Registry = ($env:DOCKER_REGISTRY ?? "codebytes")
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    Write-Host "Usage: ./push-demo.ps1 <demo_number> [tag]"
    Write-Host ""
    Write-Host "Available demos:"
    Write-Host "  1 - Policy Guardrails"
    Write-Host "  2 - Supply Chain Trust"
    Write-Host "  3 - Image Hardening"
    Write-Host "  6 - Observability Signals"
    Write-Host "  src - Source images"
    Write-Host "  all - Push all built images"
}

if ([string]::IsNullOrEmpty($DemoNumber)) {
    Show-Usage
    exit 1
}

Write-Host "🚀 Pushing Demo $DemoNumber to Docker Hub"
Write-Host "Registry: $Registry"
Write-Host "Tag: $Tag"
Write-Host ""

# Check Docker login
$dockerInfo = docker info 2>$null
if (-not ($dockerInfo | Select-String -Pattern 'Username')) {
    Write-Host "❌ Not logged into Docker Hub. Please run: docker login" -ForegroundColor Red
    exit 1
}

function Push-Image {
    param([string]$Image)
    Write-Host "Pushing $Image..."
    docker push $Image
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Pushed: $Image"
        Write-Host "   View at: https://hub.docker.com/r/$Image"
    } else {
        Write-Host "❌ Failed to push: $Image" -ForegroundColor Red
        return $false
    }
    return $true
}

switch ($DemoNumber) {
    "1" {
        Write-Host "📋 Pushing Demo 1: Policy Guardrails"
        Push-Image "$Registry/guardian-demo-secure:$Tag"
        Push-Image "$Registry/guardian-demo-insecure:$Tag"
    }
    "2" {
        Write-Host "🔒 Pushing Demo 2: Supply Chain Trust"
        Push-Image "$Registry/guardian-demo-app:$Tag"
    }
    "3" {
        Write-Host "🛡️ Pushing Demo 3: Image Hardening"
        Push-Image "$Registry/guardian-demo-vulnerable:$Tag"
        Push-Image "$Registry/guardian-demo-hardened:$Tag"
    }
    "6" {
        Write-Host "📊 Pushing Demo 6: Observability Signals"
        Push-Image "$Registry/guardian-telemetry:$Tag"
    }
    "src" {
        Write-Host "🏗️ Pushing Source Images"
        Push-Image "$Registry/guardian-demo:$Tag"
        Push-Image "$Registry/guardian-demo-base-insecure:$Tag"
    }
    "all" {
        Write-Host "🌟 Pushing All Available Images"

        # Check which images exist locally and push them
        $images = @(
            "$Registry/guardian-demo-secure:$Tag",
            "$Registry/guardian-demo-insecure:$Tag",
            "$Registry/guardian-demo-app:$Tag",
            "$Registry/guardian-demo-vulnerable:$Tag",
            "$Registry/guardian-demo-hardened:$Tag",
            "$Registry/guardian-telemetry:$Tag",
            "$Registry/guardian-demo:$Tag",
            "$Registry/guardian-demo-base-insecure:$Tag"
        )

        $localImages = docker images --format "{{.Repository}}:{{.Tag}}"
        foreach ($image in $images) {
            if ($localImages | Select-String -Pattern ([regex]::Escape($image)) -SimpleMatch) {
                Push-Image $image
            } else {
                Write-Host "⚠️ Image not found locally: $image (skipping)"
            }
        }
    }
    default {
        Write-Host "❌ Unknown demo number: $DemoNumber" -ForegroundColor Red
        Write-Host "Available: 1, 2, 3, 6, src, all"
        exit 1
    }
}

Write-Host ""
Write-Host "🎉 Push complete! Visit your Docker Hub repository:"
Write-Host "  https://hub.docker.com/u/$Registry"
