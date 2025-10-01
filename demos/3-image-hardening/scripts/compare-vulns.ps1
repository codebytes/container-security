#requires -Version 7.0
param(
    [string]$BeforeReport = "../reports/before.txt",
    [string]$AfterReport = "../reports/after.txt"
)

function Get-VulnCount {
    param([string]$ReportPath)
    if (!(Test-Path $ReportPath)) {
        throw "Report not found: $ReportPath"
    }
    $content = Get-Content $ReportPath
    $critical = ($content | Select-String "CRITICAL").Count
    $high = ($content | Select-String "HIGH").Count
    return [pscustomobject]@{ Critical = $critical; High = $high }
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
