# Interactive Policy Guardrails Demo

This enhanced demo shows the "before and after" effect of applying Kyverno admission control policies. It's designed for interactive presentations where you can pause at key points to explain concepts and answer questions.

## 🎯 Demo Flow Overview

The demo follows this narrative:

1. **Show the Problem**: Deploy insecure pods WITHOUT policies (they succeed)
2. **Apply the Solution**: Install Kyverno admission control policies  
3. **Demonstrate Protection**: Try to deploy insecure pods (they get blocked)
4. **Validate Compliance**: Show that compliant pods still work

## 🚀 Running the Interactive Demo

### Prerequisites
- Kubernetes cluster (local or remote)
- `kubectl` configured and connected
- `helm` installed (recommended)
- **Bash 4.0+ or compatible shell** (Linux/macOS/WSL)
- **PowerShell 7+** (Windows alternative)

### Bash Compatibility
✅ **Fully tested and compatible with:**
- Bash 4.0+ (Linux distributions)  
- Bash 5.x (macOS with Homebrew, modern Linux)
- WSL/WSL2 Bash (Windows Subsystem for Linux)
- Git Bash (Windows - limited color support)

⚠️ **Shell Features Used:**
- `read -r` for user input pauses (interactive mode)
- `[[ ]]` for enhanced conditionals (bash-specific)
- ANSI color codes for visual formatting  
- Parameter expansion with defaults `${VAR:-default}`
- Command substitution `$(command)`
- Compatible with `set -e` error handling

**Automated Mode:** Use `--automated` flag or `DEMO_AUTOMATED=true` for CI/CD pipelines and testing.

### Quick Start

**Interactive Mode (for presentations):**
```bash
# Linux/macOS/WSL
cd demos/1-policy-guardrails
./scripts/run-demo.sh

# Windows PowerShell
cd demos/1-policy-guardrails
.\scripts\run-demo-interactive.ps1
```

**Automated Mode (for testing/CI):**
```bash
# Bash - No user interaction required
./scripts/run-demo.sh --automated
DEMO_AUTOMATED=true ./scripts/run-demo.sh

# PowerShell - No user interaction required  
.\scripts\run-demo-interactive.ps1 -Automated
$env:DEMO_AUTOMATED='true'; .\scripts\run-demo-interactive.ps1

# Get help
./scripts/run-demo.sh --help
.\scripts\run-demo-interactive.ps1 -Help
```

## 📖 Detailed Walkthrough

### Phase 0: Environment Preparation (Step 1)

**What happens**: The demo automatically cleans up any leftover resources from previous runs.

**Key talking points**:
- "First, let's ensure we have a clean environment"
- "This removes any policies or resources from previous demo runs"
- "This ensures consistent results every time we run the demo"

**Behind the scenes**:
- Removes any existing Kyverno policies
- Deletes and recreates the demo namespace
- Ensures fresh start for demonstration

### Phase 1: Before Security Policies (Steps 2-4)

**What happens**: The demo creates insecure pods without any admission control.

**Key talking points**:
- "Let's see what happens in an unprotected cluster"
- Point out that root pod runs successfully with UID 0
- Show that unsigned pod has runtime issues but was allowed to be created
- Emphasize this represents the security risk

**Demo pause points**:
```bash
👆 Press ENTER to continue...
```

**Commands you can run during pause**:
```bash
# Show pod details
kubectl get pods -n demo-star-lord -o wide

# Check security context of root pod
kubectl exec root-pod -n demo-star-lord -- id

# Show pod specifications
kubectl describe pod root-pod -n demo-star-lord
```

### Phase 2: Applying Security Policies (Step 5)

**What happens**: Kyverno policies are installed and activated.

**Key talking points**:
- "Now we'll apply admission control policies"
- Explain what the policies enforce:
  - No root containers (UID 0)
  - Only 'secure' tagged images (simulating signed images)
- Show that existing pods continue running (graceful enforcement)

### Phase 3: Testing Policy Enforcement (Steps 6-7)

**What happens**: Attempts to create new insecure pods are blocked.

**Demo outputs you'll see**:
```
✅ SUCCESS: Root pod was rejected by admission control
✅ SUCCESS: Unsigned pod was rejected by admission control
```

**Key talking points**:
- "Watch what happens when we try to create the same insecure pods now"
- Point out the admission webhook denial messages
- Explain how this prevents security incidents at deployment time

**Demo outputs you'll see**:
```
Root pod user ID:
uid=0(root) gid=0(root) groups=0(root)

Unsigned pod status: Running  
uid=0(root) gid=0(root) groups=0(root)
```

**Key talking points**:
- Both insecure pods are running as root (UID 0)
- This represents the security risks in unprotected clusters
- "Anyone can deploy containers with full root privileges"
- This is exactly what we want to prevent with policies

### Phase 4: Validating Compliant Workloads (Step 8-9)

**What happens**: Shows that secure, compliant pods still work normally.

**Key talking points**:
- "Security policies shouldn't break legitimate workloads"
- Show the compliant pod specifications
- Emphasize positive security (enabling good practices, not just blocking bad ones)

## 🎨 Presentation Tips

### Visual Elements
The demo uses color coding:
- 🟡 **Yellow**: "Before" sections (showing problems)
- 🔴 **Red**: Policy enforcement (blocking bad things)
- 🟢 **Green**: Success messages and compliant operations
- 🔵 **Blue**: User interaction prompts

### Audience Interaction
At each pause, you can:
- Ask the audience what they think will happen next
- Show additional kubectl commands
- Explain the underlying technology (Kyverno, admission webhooks)
- Discuss real-world scenarios and best practices

### Key Messages to Emphasize

1. **Proactive Security**: "We catch security issues at deployment time, not runtime"

2. **Graceful Enforcement**: "Existing workloads continue running while new deployments are secured"

3. **Policy as Code**: "Security policies are versioned, auditable, and consistent across environments"

4. **Developer Experience**: "Clear error messages help developers understand and fix security issues"

## 🛠️ Customization Options

### Using Different Images
```bash
./scripts/run-demo.sh myregistry.com/myapp:latest
```

### Running Non-Interactively
For automated testing or CI/CD demonstrations:
```bash
# Use the original non-interactive version
./scripts/run-demo-original.sh
```

### Modifying Policies
Edit `policies/require-signed-nonroot.yaml` to:
- Add additional security rules
- Change image tag requirements
- Adjust security contexts

## 🧹 Cleanup

The demo provides cleanup commands at the end:
```bash
kubectl delete namespace demo-star-lord --ignore-not-found
kubectl delete clusterpolicy require-nonroot-demo --ignore-not-found
```

Or run the automated cleanup:
```bash
./scripts/cleanup.sh
```

## 🔍 Troubleshooting

### Common Issues

**Pods not being blocked**: 
- Ensure 15+ seconds have passed after policy installation
- Check admission webhook status: `kubectl get validatingadmissionpolicies`

**Image pull errors**:
- Demo uses local images (`guardian-demo:secure`, `guardian-demo:insecure`)
- These are created by the main demo setup scripts

**Permission errors**:
- Ensure kubectl has cluster-admin permissions
- Check if cluster has admission controllers enabled

### Verification Commands
```bash
# Check Kyverno status
kubectl get pods -n kyverno

# Verify policies are active
kubectl get clusterpolicy

# Check admission webhooks
kubectl get validatingwebhookconfigurations
```

## 🎓 Learning Outcomes

After this demo, audience should understand:
- How admission controllers work in Kubernetes
- The difference between preventive and detective security controls  
- Policy-as-code approach to security governance
- Practical implementation of container security best practices
- Balance between security and operational efficiency