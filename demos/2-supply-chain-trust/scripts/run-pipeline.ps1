#requires -Version 7.0
param(
    # Default to 127.0.0.1:5000 (NOT localhost:5000): on macOS, AirPlay Receiver
    # binds *:5000 and localhost->::1 hits AirPlay (HTTP 403) instead of the
    # registry. 127.0.0.1 reaches the local registry directly — the SAME registry
    # the shared cluster wires up (published on 127.0.0.1:5000), reachable
    # in-cluster as registry:5000. Pass -Registry localhost:5000 to override.
    [string]$Registry = "127.0.0.1:5000",
    [string]$ImageName = "guardian-demo-app", 
    [string]$Tag = "v0.1.0-secure"
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$projectRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
$artifactDir = Join-Path $projectRoot 'artifacts'
$sbomPath = Join-Path $artifactDir 'sbom.json'
$cosignKeyPath = Join-Path $projectRoot 'cosign.key'
$cosignPubPath = Join-Path $projectRoot 'cosign.pub'
$fullImage = "${Registry}/${ImageName}:${Tag}"

function Write-InstallInstructions {
    param([string]$Tool)

    switch ($Tool) {
        'docker' {
            Write-Host "  docker:" -ForegroundColor Yellow
            Write-Host "    Windows: winget install -e --id Docker.DockerDesktop"
            Write-Host "    macOS:   brew install --cask docker"
            Write-Host "    Manual:  https://docs.docker.com/get-docker/"
        }
        'kubectl' {
            Write-Host "  kubectl:" -ForegroundColor Yellow
            Write-Host "    Windows: winget install -e --id Kubernetes.kubectl"
            Write-Host "    macOS:   brew install kubectl"
            Write-Host "    Manual:  https://kubernetes.io/docs/tasks/tools/"
        }
        'syft' {
            Write-Host "  syft:" -ForegroundColor Yellow
            Write-Host "    Windows: winget install -e --id Anchore.Syft"
            Write-Host "    macOS:   brew install syft"
            Write-Host "    Manual:  https://github.com/anchore/syft#installation"
        }
        'trivy' {
            Write-Host "  trivy:" -ForegroundColor Yellow
            Write-Host "    Windows: winget install -e --id AquaSecurity.Trivy"
            Write-Host "    macOS:   brew install trivy"
            Write-Host "    Manual:  https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
        }
        'cosign' {
            Write-Host "  cosign:" -ForegroundColor Yellow
            Write-Host "    Windows: winget install -e --id Sigstore.Cosign"
            Write-Host "    macOS:   brew install cosign"
            Write-Host "    Manual:  https://docs.sigstore.dev/cosign/installation/"
        }
    }
}

function Test-Prerequisites {
    $requiredTools = @('docker', 'kubectl', 'syft', 'trivy', 'cosign')
    $missingTools = @()

    foreach ($tool in $requiredTools) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            $missingTools += $tool
        }
    }

    $hasError = $false
    if ($missingTools.Count -gt 0) {
        foreach ($tool in $missingTools) {
            Write-Host "ERROR: missing prerequisite: $tool" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Install the missing tool(s), then rerun this pipeline:" -ForegroundColor Cyan
        foreach ($tool in $missingTools) { Write-InstallInstructions $tool }
        $hasError = $true
    }

    if (-not (Test-Path -LiteralPath $cosignKeyPath)) {
        Write-Host "ERROR: missing prerequisite: cosign.key" -ForegroundColor Red
        Write-Host "Generate a local key pair from the demo root:" -ForegroundColor Cyan
        Write-Host "  cd `"$projectRoot`""
        Write-Host "  cosign generate-key-pair"
        Write-Host "This creates cosign.key (private, gitignored) and cosign.pub (public)."
        $hasError = $true
    }

    if ($hasError) { exit 1 }
}

# cosign 3.0.6 defaults to --use-signing-config / --new-bundle-format=true, which
# stores the signature as an OCI 1.1 referrer (tag sha256-<digest>) rather than the
# legacy sha256-<digest>.sig Kyverno's verifyImages reader expects -> Kyverno reports
# "no signatures found" and rejects everything. Force the legacy format, only adding
# flags the installed cosign supports (guards older cosign 2.x).
function Test-CosignFlag {
    param([string]$Sub, [string]$Flag)
    return (cosign $Sub --help 2>$null | Select-String -SimpleMatch $Flag) -ne $null
}
function Get-CosignSignFlags {
    $f = @('--yes', '--allow-http-registry')
    if (Test-CosignFlag 'sign' '--use-signing-config') { $f += '--use-signing-config=false' }
    if (Test-CosignFlag 'sign' '--new-bundle-format')  { $f += '--new-bundle-format=false' }
    if (Test-CosignFlag 'sign' '--tlog-upload')        { $f += '--tlog-upload=false' }
    return $f
}
function Get-CosignVerifyFlags {
    $f = @('--allow-http-registry')
    if (Test-CosignFlag 'verify' '--insecure-ignore-tlog') { $f += '--insecure-ignore-tlog=true' }
    return $f
}

Test-Prerequisites

Push-Location $projectRoot
try {
    Write-Host "=== Supply Chain Trust Pipeline ===" -ForegroundColor Cyan
    Write-Host "Registry: $Registry"
    Write-Host "Image: $ImageName"
    Write-Host "Tag: $Tag"
    Write-Host "Full Image: $fullImage"
    Write-Host ""

    # Ensure a local registry is available when targeting localhost so docker push
    # works out of the box. Prefer REUSING the registry created/wired by
    # scripts/setup-kind-cluster.ps1 (same container name `registry`, host port 5000)
    # so signed images are reachable from the kind cluster at admission. Only fall
    # back to a standalone registry if none exists.
    if ($Registry -like 'localhost:*' -or $Registry -like '127.0.0.1:*') {
        $port = $Registry.Split(':')[-1]
        $running = docker ps --format '{{.Names}}' | Select-String -Pattern '^registry$'
        if ($running) {
            $kindNet = docker inspect -f '{{json .NetworkSettings.Networks.kind}}' registry 2>$null
            if ($kindNet -and $kindNet -ne 'null') {
                Write-Host "Reusing kind-network registry ($Registry) — images are reachable from the kind cluster" -ForegroundColor Cyan
            } else {
                Write-Host "Reusing existing local registry ($Registry)" -ForegroundColor Cyan
                Write-Host "WARNING: This registry is NOT on the kind network; images won't pull from a kind cluster." -ForegroundColor Yellow
                Write-Host "         Run scripts/setup-kind-cluster.ps1 first for end-to-end admission verification." -ForegroundColor Yellow
            }
        } else {
            Write-Host "No shared registry found; starting a standalone registry on $Registry" -ForegroundColor Yellow
            Write-Host "WARNING: A standalone registry is NOT reachable from a kind cluster's nodes." -ForegroundColor Yellow
            Write-Host "         For demo 5 / signed-image admission, run scripts/setup-kind-cluster.ps1 instead." -ForegroundColor Yellow
            docker run -d -p "${port}:5000" --name registry registry:2 | Out-Null
        }
    }

    New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null

    Write-Host "[1/6] Building image $fullImage" -ForegroundColor Cyan
    docker build -f pipeline/Dockerfile -t $fullImage .

    Write-Host "[2/6] Generating SBOM" -ForegroundColor Cyan
    syft scan $fullImage -o json > $sbomPath

    Write-Host "[3/6] Scanning with Trivy" -ForegroundColor Cyan
    # Informational by default: a live Trivy DB flags unfixed base-OS HIGH/CRITICAL
    # CVEs on any practical base (incl. distroless), so a hard gate would dead-end
    # the demo. Set $env:STRICT_SCAN='1' to enforce a hard, production-style gate.
    if ($env:STRICT_SCAN -eq '1') {
        trivy image --severity HIGH,CRITICAL --exit-code 1 $fullImage
        if ($LASTEXITCODE -ne 0) {
            Write-Host "HIGH/CRITICAL vulnerabilities found - pipeline blocked (STRICT_SCAN=1)" -ForegroundColor Red
            exit 1
        }
    } else {
        trivy image --severity HIGH,CRITICAL $fullImage
        Write-Host "Scan is INFORMATIONAL (set `$env:STRICT_SCAN='1' to enforce): findings above do not block this demo." -ForegroundColor Yellow
    }

    Write-Host "[4/6] Pushing image" -ForegroundColor Cyan
    docker push $fullImage

    Write-Host "[5/6] Signing image (keyed)" -ForegroundColor Cyan
    # cosign signs the DIGEST not the tag: resolve the pushed digest so the signature
    # attaches to the exact manifest Kyverno admits. Legacy bundle format (see
    # Get-CosignSignFlags) so Kyverno can find the .sig.
    $signRef = $fullImage
    $repoDigest = (docker inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' $fullImage 2>$null |
        Select-String -SimpleMatch "${Registry}/${ImageName}@" | Select-Object -First 1)
    if ($repoDigest) {
        $signRef = $repoDigest.ToString().Trim()
        Write-Host "      Signing digest: $signRef"
    }
    cosign sign @(Get-CosignSignFlags) --key $cosignKeyPath $signRef

    Write-Host "[6/6] Verifying signature (keyed)" -ForegroundColor Cyan
    cosign verify @(Get-CosignVerifyFlags) --key $cosignPubPath $signRef

    Write-Host "Pipeline completed" -ForegroundColor Green
    Write-Host "SBOM stored in: artifacts/sbom.json"
    Write-Host "Next step — run the in-cluster admission demo fully automatically" -ForegroundColor Cyan
    Write-Host "(enables Kyverno insecure-registry access, injects the public key, applies the"
    Write-Host " policy, deploys signed ADMITTED, builds+deploys a DISTINCT unsigned REJECTED):"
    Write-Host "     ./scripts/setup-admission.ps1 -Registry $Registry -ImageName $ImageName -Tag $Tag"
    Write-Host "Tear it down with: ./scripts/cleanup.ps1"
} finally {
    Pop-Location
}
