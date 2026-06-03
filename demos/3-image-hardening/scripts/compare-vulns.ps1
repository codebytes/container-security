#requires -Version 7.0
param(
    [string]$BeforeReport = "../reports/before.json",
    [string]$AfterReport = "../reports/after.json"
)

# Counts real Trivy findings from JSON reports. Grepping the table output is
# unreliable (it counts legend/header lines), so we parse JSON instead.
function Get-VulnCount {
    param([string]$ReportPath)
    if (!(Test-Path $ReportPath)) {
        throw "Report not found: $ReportPath (run ./run-demo.ps1 to generate JSON reports)"
    }
    $report = Get-Content $ReportPath -Raw | ConvertFrom-Json
    $critical = 0
    $high = 0
    foreach ($result in $report.Results) {
        if ($null -ne $result.Vulnerabilities) {
            $critical += ($result.Vulnerabilities | Where-Object { $_.Severity -eq "CRITICAL" }).Count
            $high += ($result.Vulnerabilities | Where-Object { $_.Severity -eq "HIGH" }).Count
        }
    }
    return [pscustomobject]@{ Critical = [int]$critical; High = [int]$high }
}

$before = Get-VulnCount -ReportPath $BeforeReport
$after = Get-VulnCount -ReportPath $AfterReport

$deltaCritical = $before.Critical - $after.Critical
$deltaHigh = $before.High - $after.High

Write-Host "Baseline -> Hardened Vulnerability Reduction" -ForegroundColor Cyan
Write-Host "Critical: $($before.Critical) -> $($after.Critical) (Δ $deltaCritical)"
Write-Host "High: $($before.High) -> $($after.High) (Δ $deltaHigh)"

if ($deltaCritical -lt 0 -or $deltaHigh -lt 0) {
    Write-Warning "Hardened image still has more vulnerabilities than baseline."
} else {
    Write-Host "Improvement achieved." -ForegroundColor Green
}
