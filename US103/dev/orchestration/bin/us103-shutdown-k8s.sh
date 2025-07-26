#!/bin/bash
# us103-shutdown-k8s.sh - Gracefully cordon and shut down all K8s VMs at site US103
#
# Phase 1: Cordon each node using kubectl (run locally from the jump station)
# Phase 2: Shutdown each VM over SSH (using hostname or fallback IP lookup)
#
# VM names come from:
#   /orchestration/vars/global/US103-k8s-servers.vars
# Optional overrides:
#   /orchestration/vars/optional/us103-shutdown-k8s.vars

set -euo pipefail

SCRIPT_NAME=$(basename "$0" .sh)
VARS_FILE="/orchestration/vars/global/US103-k8s-servers.vars"
OPTIONAL_VARS="/orchestration/vars/optional/${SCRIPT_NAME}.vars"
GET_IP_SCRIPT="$(dirname "$0")/us103-get-xo-vm-ip.sh"

# Ensure vars file is present
if [[ ! -f "$VARS_FILE" ]]; then
    echo "❌ Missing required vars file: $VARS_FILE"
    exit 1
fi
source "$VARS_FILE"

# Load optional overrides
[[ -f "$OPTIONAL_VARS" ]] && source "$OPTIONAL_VARS"

# --- Function: Cordon a node across all available kube contexts ---
cordon_node() {
    local nodename="$1"
    local found=0
    for ctx in $(kubectl config get-contexts -o name); do
        if kubectl --context="$ctx" get node "$nodename" &>/dev/null; then
            echo "🔒 Cordon: $nodename (context: $ctx)"
            kubectl --context="$ctx" cordon "$nodename"
            found=1
        fi
    done
    [[ "$found" -eq 0 ]] && echo "⚠️  Node $nodename not found in any context"
}

# --- Phase 1: Cordon all nodes first ---
echo "📌 Cordoning all Kubernetes nodes first..."
for vm in "${K8S_VMS[@]}"; do
    cordon_node "$vm"
done

# --- Phase 2: Shutdown each VM ---
echo "🔻 Shutting down all VMs..."
for vm in "${K8S_VMS[@]}"; do
    echo "➡️  Processing $vm..."

    # Try SSH via hostname
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$vm" "true" 2>/dev/null; then
        TARGET="$vm"
    else
        echo "🔎 Host $vm not reachable by name, trying IP lookup..."
        TARGET=$("$GET_IP_SCRIPT" "$vm")
        if [[ -z "$TARGET" ]]; then
            echo "❌ Could not resolve IP for $vm, skipping shutdown."
            continue
        fi
    fi

    echo "⏻ Sending shutdown command to $vm ($TARGET)..."
    ssh "$TARGET" "sudo shutdown -h now" || echo "⚠️  Shutdown failed for $vm"
done

