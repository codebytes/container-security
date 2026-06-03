#!/usr/bin/env bash
set -euo pipefail

# Counts real Trivy findings from JSON reports. Defaults to the JSON output
# produced by run-demo.sh. Grepping the human-readable table is unreliable
# (it counts legend/header lines), so we parse JSON with jq instead.
BEFORE_REPORT="${1:-../reports/before.json}"
AFTER_REPORT="${2:-../reports/after.json}"

if ! command -v jq &> /dev/null; then
    echo "jq is required to parse Trivy JSON reports. Install jq and retry." >&2
    exit 1
fi

get_vuln_count() {
    local report_path="$1"
    if [[ ! -f "$report_path" ]]; then
        echo "Report not found: $report_path (run ./run-demo.sh to generate JSON reports)" >&2
        exit 1
    fi
    local critical high
    critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$report_path")
    high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$report_path")
    echo "$critical $high"
}

read -r before_critical before_high < <(get_vuln_count "$BEFORE_REPORT")
read -r after_critical after_high < <(get_vuln_count "$AFTER_REPORT")

delta_critical=$((before_critical - after_critical))
delta_high=$((before_high - after_high))

echo -e "\033[36mBaseline -> Hardened Vulnerability Reduction\033[0m"
echo "Critical: $before_critical -> $after_critical (Δ $delta_critical)"
echo "High: $before_high -> $after_high (Δ $delta_high)"

if [[ $delta_critical -lt 0 ]] || [[ $delta_high -lt 0 ]]; then
    echo -e "\033[33mWarning: Hardened image still has more vulnerabilities than baseline.\033[0m"
else
    echo -e "\033[32mImprovement achieved.\033[0m"
fi
