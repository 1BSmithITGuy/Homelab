#!/bin/bash
#----------------------------------------------------------------------------------------------------------------
#  Bryan Smith
#  BSmithITGuy@gmail.com
#  Last Update:  07/19/2025

# DESCRIPTION:
  # This script will power on the entire k8s cluster, wait for all the worker nodes to be ready, then uncordon them.
  # The nodes will have been cordoned if shutdown with the shutdown-k8s-cluster.sh companion script
          #  The companion script saves the current running nodes it cordoned/shutdown in a text file (CORDON_LIST)
          #  The nodes are cordoned at shutdown to avoid the master starting pods on the first node that it sees on startup.
  # The nodes are powered on according to VM_NAMES in Xen Orchstra (XO) running xcp-ng (8.3.0) hosts using the xo-cli.
  #  There are log filesand work files located in /bss-scripts (see LOG_FILE)

#  PREREQUISITES
  # This script is intended to be run on an Ubuntu jump station that also runs shutdown-k8s-cluster.sh
  # You need to have installed/configured xo-xli (see readme.md for Jump station)
  # kubectl config context on the jump station needs to be set to the correct cluster


#     Need to update:  
        # use the CORDONE _LIST for which nodes to power on in Xen Orchestra
             # but need to make sure the hostname matches the VM name in XO.
#----------------------------------------------------------------------------------------------------------------


# === Configuration ===
SSH_USER="bssadm"
WORK_DIR="/bss-scripts/k8s/shutdown-k8s-cluster/workingdir"
STARTUP_LOG_DIR="/bss-scripts/k8s/startup-k8s-cluster/logs"
CORDON_LIST="$WORK_DIR/worker-nodes.txt"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$STARTUP_LOG_DIR/startup-log-$TIMESTAMP.log"
XO_CLI=$(which xo-cli)
VM_NAMES=("bsus103k-8m01" "bsus103k-8w01" "bsus103k-8w02")
VM_IPS=("10.0.2.20" "10.0.2.22" "10.0.2.23")

# === Ensure Log Directory Exists (with fallback to sudo) ===
if [ ! -d "$STARTUP_LOG_DIR" ]; then
    echo "📁 Creating log directory $STARTUP_LOG_DIR..."
    sudo mkdir -p "$STARTUP_LOG_DIR" || {
        echo "❌ Failed to create log directory."
        exit 1
    }
    sudo chown "$USER:$USER" "$STARTUP_LOG_DIR"
fi

# === Setup Logging ===
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🚀 Kubernetes cluster startup started at $TIMESTAMP"

# === Start each VM ===
echo "📦 Starting Kubernetes VMs using xo-cli..."
for vm in "${VM_NAMES[@]}"; do
    uuid=$($XO_CLI list-objects type=VM | jq -r ".[] | select(.name_label==\"$vm\") | .id")
    if [ -n "$uuid" ]; then
        echo "  - Starting $vm (UUID: $uuid)"
        $XO_CLI rest post vms/"$uuid"/actions/start
        sleep 5
    else
        echo "  ⚠️ VM $vm not found in xo-cli output."
    fi
done

# === Wait for VMs to become reachable ===
echo "⏳ Waiting for VMs to respond to ping..."
for ip in "${VM_IPS[@]}"; do
    echo "  - Waiting for $ip..."
    until ping -c1 -W1 "$ip" &>/dev/null; do
        sleep 2
    done
    echo "    ✅ $ip is reachable."
done

# === Wait for Kubernetes nodes to become Ready ===
echo "⏳ Waiting for all Kubernetes nodes to be Ready..."
until kubectl get nodes 2>/dev/null | grep -vq NotReady && kubectl get nodes | grep -q Ready; do
    echo "  - Checking node readiness..."
    sleep 5
done
echo "✅ All nodes are Ready."

# === Uncordon previously cordoned worker nodes ===
if [ -f "$CORDON_LIST" ]; then
    echo "🔓 Uncordoning worker nodes from $CORDON_LIST..."
    while IFS=' ' read -r node_name node_ip; do
        echo "  - Uncordoning $node_name"
        kubectl uncordon "$node_name"
    done < "$CORDON_LIST"
else
    echo "⚠️ $CORDON_LIST not found. Skipping uncordon step."
fi

echo "✅ Kubernetes cluster startup completed."
echo "📝 Log file saved to $LOG_FILE"

