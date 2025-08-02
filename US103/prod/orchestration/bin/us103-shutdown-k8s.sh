#!/bin/bash
#----------------------------------------------------------------------------------------------------------------
#  Bryan Smith
#  BSmithITGuy@gmail.com
#  Last Update:  08/02/2025
#
#  DESCRIPTION:
#    Gracefully shuts down the Kubernetes cluster nodes for US103, including optional stack VMs and worker/master nodes.
#
#  PREREQUISITES:
#    - Kubernetes context must be reachable
#    - VM list defined in vars/global/US103-k8s-servers.vars
#    - Optional VM list in vars/optional/us103-start-k8s.vars
#----------------------------------------------------------------------------------------------------------------


set -euo pipefail

SSH_USER="bssadm"  # Matches your sudoers configuration

VARS_DIR="$(dirname "${BASH_SOURCE[0]}")/../vars"
LIBEXEC_DIR="$(dirname "${BASH_SOURCE[0]}")/../libexec"

GLOBAL_K8S_VARS="${VARS_DIR}/global/US103-k8s-servers.vars"
OPTIONAL_STACK_VARS="${VARS_DIR}/optional/us103-start-k8s.vars"

# Load context and worker list
source "$GLOBAL_K8S_VARS"
KUBECTL_CONTEXT="$context"
WORKERS=("${workers[@]}")

# Step 1: Shutdown additional stack VMs via XO
if [[ -f "$OPTIONAL_STACK_VARS" ]]; then
    echo "[INFO] Shutting down additional stack VMs listed in: $OPTIONAL_STACK_VARS"
    mapfile -t ADDITIONAL_VMS < "$OPTIONAL_STACK_VARS"
    for vm_name in "${ADDITIONAL_VMS[@]}"; do
        echo "[INFO] Attempting shutdown of additional VM: $vm_name"
        "$LIBEXEC_DIR/us103-shutdown-xo-vm.sh" "$vm_name"
    done
else
    echo "[INFO] No optional stack VMs to shut down."
fi

# Step 2: Build map of node name -> IP
echo "[INFO] Mapping node names to IP addresses..."
declare -A NODE_IP_MAP
while read -r name ip; do
    NODE_IP_MAP["$name"]="$ip"
done < <(kubectl --context="$KUBECTL_CONTEXT" get nodes -o wide | awk 'NR>1 {print $1, $6}')

# Step 3: Cordon all worker nodes and collect shutdown list
echo "[INFO] Cordoning all worker nodes..."
SHUTDOWN_NODES=()
while read -r node; do
    [[ -z "$node" ]] && continue
    if kubectl --context="$KUBECTL_CONTEXT" get node "$node" -o jsonpath='{.spec.unschedulable}' 2>/dev/null | grep -q "true"; then
        echo "[INFO] $node is already cordoned. Skipping."
    else
        echo "[INFO] Cordoning $node"
        kubectl --context="$KUBECTL_CONTEXT" cordon "$node"
    fi
    SHUTDOWN_NODES+=("$node")
done < <(kubectl --context="$KUBECTL_CONTEXT" get nodes --no-headers | grep -v 'control-plane' | awk '{print $1}')

# Step 4: Shutdown worker nodes by IP
echo "[INFO] Shutting down worker nodes..."
for node in "${SHUTDOWN_NODES[@]}"; do
    ip="${NODE_IP_MAP[$node]}"
    if [[ -n "$ip" ]]; then
        echo "[INFO] Shutting down worker node: $node ($ip)"
        if ssh -o BatchMode=yes "$SSH_USER@$ip" "sudo /sbin/shutdown now"; then
            echo "[INFO] Shutdown command issued to $node ($ip)"
        else
            RC=$?
            if [[ $RC -eq 255 ]]; then
                echo "[INFO] SSH closed — $node ($ip) is shutting down."
            else
                echo "[WARN] Failed to shutdown worker node: $node ($ip) (exit code $RC)"
            fi
        fi
    else
        echo "[WARN] No IP found for worker node: $node"
    fi
done

# Step 5: Identify and shutdown control-plane (master) node
CONTROL_PLANE_NODE=$(kubectl --context="$KUBECTL_CONTEXT" get nodes --selector='node-role.kubernetes.io/control-plane' -o name | awk -F/ '{print $2}' | head -n 1)

if [[ -n "$CONTROL_PLANE_NODE" ]]; then
    MASTER_IP="${NODE_IP_MAP[$CONTROL_PLANE_NODE]}"
    if [[ -n "$MASTER_IP" ]]; then
        echo "[INFO] Shutting down master node: $CONTROL_PLANE_NODE ($MASTER_IP)"
        if ssh -o BatchMode=yes "$SSH_USER@$MASTER_IP" "sudo /sbin/shutdown now"; then
            echo "[INFO] Shutdown command issued to master $CONTROL_PLANE_NODE ($MASTER_IP)"
        else
            RC=$?
            if [[ $RC -eq 255 ]]; then
                echo "[INFO] SSH closed — master $CONTROL_PLANE_NODE ($MASTER_IP) is shutting down."
            else
                echo "[WARN] Failed to shutdown master node: $CONTROL_PLANE_NODE ($MASTER_IP) (exit code $RC)"
            fi
        fi
    else
        echo "[ERROR] Could not resolve IP for master node: $CONTROL_PLANE_NODE" >&2
    fi
else
    echo "[ERROR] Could not identify a control-plane (master) node." >&2
fi

