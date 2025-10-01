#!/usr/bin/env bash
set -euo pipefail

# Interactive pause function
pause() {
    echo ""
    echo -e "\033[33mPress Enter to continue...\033[0m"
    read -r
}

echo -e "\033[36m╔════════════════════════════════════════════╗\033[0m"
echo -e "\033[36m║  Runtime Detection Demo with Falco        ║\033[0m"
echo -e "\033[36m╚════════════════════════════════════════════╝\033[0m"
echo ""
echo "This demo will:"
echo "  1. Install Falco runtime security monitoring"
echo "  2. Add custom detection rules"
echo "  3. Trigger suspicious behaviors"
echo "  4. Show how Falco detects them in real-time"
echo ""

pause

echo -e "\033[36m[1/5] Ensuring namespaces\033[0m"
kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace demo-drax --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespaces created"

pause

echo -e "\033[36m[2/5] Installing Falco with custom detection rules\033[0m"
echo "Installing Falco with:"
echo "  - Modern eBPF driver (no kernel headers needed)"
echo "  - Custom rule to detect writes to /etc"
echo ""
helm repo add falcosecurity https://falcosecurity.github.io/charts 2>/dev/null || true
helm repo update > /dev/null
helm upgrade --install falco falcosecurity/falco \
  --namespace falco \
  --values ../manifests/falco-values.yaml \
  --wait
echo ""
echo "✅ Falco installed with custom rules"
echo ""
echo -e "\033[33mCustom Rule Details:\033[0m"
echo "  - Name: Write Below Etc Demo"
echo "  - Detects: Container writes to /etc directory"
echo "  - Priority: WARNING"
echo "  - Captures: user, command, file, container, namespace, pod"

pause

echo -e "\033[36m[3/5] Deploying trigger pod\033[0m"
echo "Deploying a pod that will perform multiple suspicious activities:"
echo "  - Writing to /etc/shadow"
echo "  - Writing to /etc/passwd"
echo "  - Creating files in /etc"
echo "  - Modifying cron configurations"
echo ""

# Delete existing trigger pod if it exists to ensure fresh run
kubectl delete -f ../manifests/trigger-pod.yaml --ignore-not-found > /dev/null 2>&1 || true
sleep 2

kubectl apply -f ../manifests/trigger-pod.yaml
echo "Waiting for trigger pod to execute suspicious actions..."
sleep 8
echo "✅ Trigger pod executed multiple suspicious actions"

pause

echo -e "\033[36m[4/5] Checking Falco alerts\033[0m"
echo "Looking for detection alerts..."
echo ""

# Try multiple times to catch alerts
for i in {1..3}; do
    ALERTS=$(kubectl logs -n falco daemonset/falco -c falco --since=30s 2>/dev/null | grep "Write below /etc detected" || true)
    if [[ -n "$ALERTS" ]]; then
        echo -e "\033[32m✅ Found Falco alerts!\033[0m"
        echo ""

        # Count the different files detected
        SHADOW_COUNT=$(echo "$ALERTS" | grep -c "/etc/shadow" || true)
        PASSWD_COUNT=$(echo "$ALERTS" | grep -c "/etc/passwd" || true)
        EVIL_COUNT=$(echo "$ALERTS" | grep -c "/etc/evil.conf" || true)
        CRON_COUNT=$(echo "$ALERTS" | grep -c "/etc/crontabs" || true)

        echo -e "\033[36mDetected suspicious writes to /etc:\033[0m"
        [[ $SHADOW_COUNT -gt 0 ]] && echo "  🔴 $SHADOW_COUNT write(s) to /etc/shadow (password file)"
        [[ $PASSWD_COUNT -gt 0 ]] && echo "  🔴 $PASSWD_COUNT write(s) to /etc/passwd (user accounts)"
        [[ $EVIL_COUNT -gt 0 ]] && echo "  🔴 $EVIL_COUNT write(s) to /etc/evil.conf (suspicious file)"
        [[ $CRON_COUNT -gt 0 ]] && echo "  🔴 $CRON_COUNT write(s) to /etc/crontabs/root (scheduled tasks)"

        echo ""
        echo -e "\033[36mSample alert details:\033[0m"
        kubectl logs -n falco daemonset/falco -c falco --since=30s 2>/dev/null | grep "Write below /etc detected" | head -3
        break
    else
        if [[ $i -lt 3 ]]; then
            echo "Attempt $i: No alerts yet, waiting 3 seconds..."
            sleep 3
        else
            echo -e "\033[33m⚠️  No alerts found yet.\033[0m"
            echo ""
            echo "This can happen if:"
            echo "  - Falco is still starting up"
            echo "  - The trigger pod hasn't executed yet"
            echo ""
            echo "Try checking manually:"
            echo "  kubectl logs -n falco daemonset/falco -c falco --tail=50 | grep -i 'etc'"
            echo "  kubectl logs -n demo-drax falco-trigger"
        fi
    fi
done

pause

echo -e "\033[36m[5/5] Cleanup\033[0m"
echo "Removing trigger pod..."
kubectl delete -f ../manifests/trigger-pod.yaml --ignore-not-found
echo ""
echo -e "\033[33mNote:\033[0m Falco remains installed for further exploration."
echo "To view live alerts: kubectl logs -n falco daemonset/falco -f"
echo "To uninstall: ./cleanup.sh"

echo ""
echo -e "\033[32m✅ Demo complete!\033[0m"