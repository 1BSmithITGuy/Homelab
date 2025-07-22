#!/bin/bash
#----------------------------------------------------------------------------------------------------------------
#  Bryan Smith
#  BSmithITGuy@gmail.com
#  Last Update:  07/21/2025

#  DESCRIPTION:
    #   Shuts down AD Domain Controllers by VM name (static - "INFUS103DC01" "INFUS103DC02")
    #   xo-cli is used to dynamically find all hosts assigned to Xen Orchestra, and then SSH is used to shutdown the VMs. 

#  PREREQUISITES
    #   This script is intended to be run on an Ubuntu jump station that has xo-cli and SSH keys to the XCP-NG hosts setup
        #   See jump station readme.md for instructions
#----------------------------------------------------------------------------------------------------------------

BASE_DIR="/bss-scripts/k8s/shutdown-ADDS-DCs"
LOG_DIR="$BASE_DIR/logs"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/shutdown-log-$TIMESTAMP.log"

SSH_USER="root"
XO_CLI=$(which xo-cli)
VM_NAMES=("INFUS103DC01" "INFUS103DC02")

# === Ensure Log Directory Exists ===
if [ ! -d "$LOG_DIR" ]; then
    echo "📁 Creating log directory $LOG_DIR..."
    sudo mkdir -p "$LOG_DIR" || {
        echo "❌ Failed to create log directory."
        exit 1
    }
    sudo chown "$USER:$USER" "$LOG_DIR"
fi

# === Setup Logging ===
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🛑 ADDS Domain Controller shutdown started at $TIMESTAMP"
echo "🔍 Fetching host IPs via xo-cli..."

# Dynamically pull host IPs from Xen Orchestra
HOST_IPS=($($XO_CLI list-objects | jq -r '.[] | select(.type=="host") | .address'))

if [ ${#HOST_IPS[@]} -eq 0 ]; then
    echo "❌ No host IPs found. Is xo-cli output complete?"
    exit 1
fi

for VM in "${VM_NAMES[@]}"; do
    echo "🔄 Searching for $VM across all XCP-ng hosts..."
    for HOST in "${HOST_IPS[@]}"; do
        echo "  📡 Trying host $HOST..."
        ssh "$SSH_USER@$HOST" "xe vm-shutdown name-label=\"$VM\"" >/dev/null 2>&1 && {
            echo "✅ $VM shutdown issued on $HOST."
            break
        }
    done
done

echo "✅ ADDS Domain Controller shutdown completed."
echo "📝 Log file saved to $LOG_FILE"

