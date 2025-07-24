#!/bin/bash
#-------------------------------------------------------------------------------------------------
#  start-k8s-stack.sh
#-------------------------------------------------------------------------------------------------
#  DESCRIPTION:
#     This script powers on Active Directory Domain Controllers (AD DCs) if DNS is not available,
#     then powers on Kubernetes master/worker nodes. It waits until all nodes are Ready, then
#     uncordons workers. It optionally powers on additional VMs defined in an optional vars file.
#
#  FILES USED:
#     - ../libexec/us103-start-xo-vm.sh       → VM startup helper using xo-cli
#     - ../../orchestration/vars/global/US103-AD-DCs.vars   → List of AD DC VMs and their IPs
#     - ../../orchestration/vars/global/US103-k8s-servers.vars → List of K8s VM names
#     - ../../orchestration/vars/optional/start-k8s-stack.vars → Optional VMs to start after K8s (optional)
#
#  REQUIREMENTS:
#     - Jump station must have working `xo-cli`, `kubectl`, and `jq`
#     - Active context must be 'us103-kubeadm01'
#-------------------------------------------------------------------------------------------------

set -euo pipefail

# === Configuration ===
REQUIRED_CONTEXT="us103-kubeadm01"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

START_VM_SCRIPT="$REPO_ROOT/orchestration/libexec/us103-start-xo-vm.sh"
AD_VARS="$REPO_ROOT/orchestration/vars/global/US103-AD-DCs.vars"
K8S_VARS="$REPO_ROOT/orchestration/vars/global/US103-k8s-servers.vars"
OPTIONAL_VARS="$REPO_ROOT/orchestration/vars/optional/$(basename "$0" .sh).vars"
CORDON_LIST="/bss-scripts/k8s/shutdown-k8s-cluster/workingdir/worker-nodes.txt"

# === Verify kubectl context ===
CURRENT_CONTEXT=$(kubectl config current-context)
if [[ "$CURRENT_CONTEXT" != "$REQUIRED_CONTEXT" ]]; then
    echo "❌ Current kubectl context is '$CURRENT_CONTEXT', expected '$REQUIRED_CONTEXT'."
    echo "💡 Use: kubectl config use-context $REQUIRED_CONTEXT"
    exit 1
fi

# === Function: check if any AD DNS server is reachable (port 53) ===
check_dns_up() {
    while IFS=',' read -r vm_name ip; do
        [[ "$vm_name" =~ ^#.*$ || -z "$vm_name" ]] && continue  # Skip comments and blanks
        echo "🔍 Checking DNS on $vm_name ($ip)..."
        if timeout 1 bash -c "</dev/tcp/$ip/53" &>/dev/null; then
            echo "✅ DNS responding on $ip"
            return 0
        fi
    done < "$AD_VARS"
    return 1
}

# === Step 1: Ensure AD DNS is running ===
echo "🔄 Checking if any AD DNS is up..."
if ! check_dns_up; then
    echo "📡 DNS not up — starting AD Domain Controllers..."

    AD_VMS=()
    while IFS=',' read -r vm_name ip; do
        [[ "$vm_name" =~ ^#.*$ || -z "$vm_name" ]] && continue
        AD_VMS+=("$vm_name")
    done < "$AD_VARS"

    "$START_VM_SCRIPT" "${AD_VMS[@]}"

    echo "⏳ Waiting for DNS to come online..."
    until check_dns_up; do
        echo "  - Still waiting..."
        sleep 3
    done
fi

# === Step 2: Start Kubernetes VMs ===
echo "🚀 Starting Kubernetes cluster VMs..."
mapfile -t K8S_VMS < <(grep -v '^#' "$K8S_VARS" | grep -v '^$' | awk -F',' '{print $1}')
"$START_VM_SCRIPT" "${K8S_VMS[@]}"

# === Step 3: Wait for Kubernetes nodes to be Ready ===
echo "⏳ Waiting for Kubernetes nodes to be Ready..."
until kubectl get nodes 2>/dev/null | grep -vq NotReady && kubectl get nodes | grep -q Ready; do
    echo "  - Checking node readiness..."
    sleep 5
done
echo "✅ All Kubernetes nodes are Ready."

# === Step 4: Uncordon previously cordoned worker nodes ===
if [ -f "$CORDON_LIST" ]; then
    echo "🔓 Uncordoning worker nodes from $CORDON_LIST..."
    while IFS=' ' read -r node_name node_ip; do
        [[ "$node_name" =~ ^#.*$ || -z "$node_name" ]] && continue
        echo "  - Uncordoning $node_name"
        kubectl uncordon "$node_name"
    done < "$CORDON_LIST"
else
    echo "⚠️ CORDON_LIST not found. Skipping uncordon step."
fi

# === Step 5: Optional VMs ===
if [[ -f "$OPTIONAL_VARS" ]]; then
    echo "📦 Found optional VM list: $(basename "$OPTIONAL_VARS")"
    mapfile -t OPTIONAL_VMS < <(grep -v '^#' "$OPTIONAL_VARS" | grep -v '^$' | awk -F',' '{print $1}')
    if [ "${#OPTIONAL_VMS[@]}" -gt 0 ]; then
        echo "🚀 Starting optional VMs..."
        "$START_VM_SCRIPT" "${OPTIONAL_VMS[@]}"
    fi
else
    echo "ℹ️ No optional VM file found at $OPTIONAL_VARS"
fi

echo "🏁 Stack startup complete."

