#!/bin/bash
#----------------------------------------------------------------------------------
#  start-k8s-stack.sh
#  Starts AD domain controllers if DNS is not up, then starts Kubernetes servers.
#----------------------------------------------------------------------------------

set -euo pipefail

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
AD_VARS="$BASE_DIR/vars/US103-AD-DCs.vars"
K8S_VARS="$BASE_DIR/vars/US103-k8s-servers.vars"
START_VM_SCRIPT="$BASE_DIR/libexec/us103-start-xo-vm.sh"

# === Function to check if any AD DNS is responding ===
check_dns_up() {
    while IFS=',' read -r vm_name ip; do
        echo "🔍 Checking DNS (port 53) on $vm_name ($ip)..."
        if timeout 1 bash -c "</dev/tcp/$ip/53" &>/dev/null; then
            echo "✅ DNS responding on $ip"
            return 0
        fi
    done < "$AD_VARS"

    return 1
}

# === 1. Ensure DNS is up ===
echo "🔄 Checking if any AD DNS is up..."
if ! check_dns_up; then
    echo "❌ No DNS responding. Starting AD domain controllers..."
    AD_VMS=()
    while IFS=',' read -r vm_name ip; do
        AD_VMS+=("$vm_name")
    done < "$AD_VARS"

    "$START_VM_SCRIPT" "${AD_VMS[@]}"

    echo "⏳ Waiting for DNS to come online..."
    until check_dns_up; do
        echo "  - Still waiting..."
        sleep 3
    done
fi

# === 2. Start Kubernetes VMs ===
echo "🚀 Starting Kubernetes VMs..."
mapfile -t K8S_VMS < "$K8S_VARS"
"$START_VM_SCRIPT" "${K8S_VMS[@]}"

# === 3. Wait for all K8s nodes to be Ready ===
echo "⏳ Waiting for Kubernetes nodes to be Ready..."
until kubectl get nodes 2>/dev/null | grep -vq NotReady && kubectl get nodes | grep -q Ready; do
    echo "  - Checking node readiness..."
    sleep 5
done
echo "✅ All Kubernetes nodes are Ready."

# === 4. Uncordon previously cordoned worker nodes ===
CORDON_LIST="/bss-scripts/k8s/shutdown-k8s-cluster/workingdir/worker-nodes.txt"
if [ -f "$CORDON_LIST" ]; then
    echo "🔓 Uncordoning worker nodes from $CORDON_LIST..."
    while IFS=' ' read -r node_name node_ip; do
        echo "  - Uncordoning $node_name"
        kubectl uncordon "$node_name"
    done < "$CORDON_LIST"
else
    echo "⚠️ CORDON_LIST not found. Skipping uncordon step."
fi

echo "🏁 K8s stack startup complete."
