#!/usr/bin/env bash
set -euo pipefail

BEFORE_REPORT="${1:-../reports/before.txt}"
AFTER_REPORT="${2:-../reports/after.txt}"

get_vuln_count() {
    local report_path="$1"
    if [[ ! -f "$report_path" ]]; then
        echo "Report not found: $report_path" >&2
        exit 1
    fi
    local critical=$(grep -c "CRITICAL" "$report_path" || true)
    local high=$(grep -c "HIGH" "$report_path" || true)
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