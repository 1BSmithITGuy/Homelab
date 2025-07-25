#!/bin/bash
#
# Shuts down the Kubernetes cluster for US103.
#
# Loads:
#   - /orchestration/vars/global/US103-k8s-servers.vars
#   - Optional: /orchestration/vars/optional/us103-shutdown-k8s.sh.vars
#
# Attempts to SSH into each node. If it's a K8s node, cordon and drain. If it's Linux, shut down via SSH.
# If SSH fails, fall back to Xen Orchestra VM shutdown.

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

GLOBAL_VARS="$REPO_ROOT/vars/global/US103-k8s-servers.vars"
OPTIONAL_VARS="$REPO_ROOT/vars/optional/${SCRIPT_NAME}.vars"
SHUTDOWN_VM_SCRIPT="$REPO_ROOT/libexec/us103-shutdown-xo-vm.sh"

declare -A K8S_MAP

echo "[$SCRIPT_NAME] Loading global vars: $GLOBAL_VARS"
while IFS='=' read -r vm ip; do
    [[ -z "$vm" || "$vm" =~ ^# ]] && continue
    K8S_MAP["$vm"]="$ip"
done < "$GLOBAL_VARS"

if [[ -f "$OPTIONAL_VARS" ]]; then
    echo "[$SCRIPT_NAME] Loading optional vars: $OPTIONAL_VARS"
    # shellcheck source=/dev/null
    source "$OPTIONAL_VARS"
fi

for vm in "${!K8S_MAP[@]}"; do
    ip="${K8S_MAP[$vm]}"
    echo "[$SCRIPT_NAME] Processing $vm at $ip"

    if timeout 5s ssh -o BatchMode=yes -o ConnectTimeout=5 "$ip" "true" 2>/dev/null; then
        echo "  → SSH reachable: $ip"

        if ssh "$ip" "command -v kubectl >/dev/null"; then
            echo "  → Node is Kubernetes. Cordon and drain..."
            ssh "$ip" "
                kubectl cordon \$(hostname) &&                 kubectl drain \$(hostname) --ignore-daemonsets --delete-emptydir-data --force
                sudo shutdown -h now
            " || echo "  ⚠️ Failed to cordon/drain $vm"
        else
            echo "  → Non-K8s Linux. Shutting down via SSH."
            ssh "$ip" "sudo shutdown -h now"
        fi
    else
        echo "  ⚠️ $vm ($ip) unreachable via SSH — falling back to XO shutdown"
        "$SHUTDOWN_VM_SCRIPT" "$vm"
    fi
done
