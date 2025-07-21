#!/bin/bash
#----------------------------------------------------------------------------------------------------------------
#  Bryan Smith
#  BSmithITGuy@gmail.com
#  Last Update:  07/21/2025
#
#  DESCRIPTION:
#    Starts AD Domain Controllers in order using xo-cli.
#    Waits for INFUS103DC01 (10.0.1.2) to be pingable before starting INFUS103DC02 (10.0.1.3).
#    Skips INFUS103TS01.
#----------------------------------------------------------------------------------------------------------------

# === Configuration ===
BASE_DIR="/bss-scripts/k8s/startup-ADDS-DCs"
LOG_DIR="$BASE_DIR/logs"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/startup-log-$TIMESTAMP.log"
XO_CLI=$(which xo-cli)

DC1_NAME="INFUS103DC01"
DC2_NAME="INFUS103DC02"
DC1_IP="10.0.1.2"
DC2_IP="10.0.1.3"

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

echo "🚀 ADDS Domain Controller startup started at $TIMESTAMP"
echo "🔎 Using xo-cli at: $XO_CLI"

# === Fetch VM list ===
echo "📋 Fetching VM list from XO..."
VM_LIST=$($XO_CLI list-objects type=VM)

# === Start DC1 and wait until reachable ===
UUID1=$(echo "$VM_LIST" | jq -r ".[] | select(.name_label==\"$DC1_NAME\") | .id")
if [ -n "$UUID1" ]; then
    echo "🚀 Starting $DC1_NAME (UUID: $UUID1)..."
    $XO_CLI rest post vms/"$UUID1"/actions/start

    echo "📡 Waiting for $DC1_NAME ($DC1_IP) to respond to ping..."
    until ping -c1 -W1 "$DC1_IP" &>/dev/null; do
        sleep 2
    done
    echo "✅ $DC1_NAME is reachable."
else
    echo "⚠️ VM '$DC1_NAME' not found in XO. Skipping."
fi

# === Start DC2 ===
UUID2=$(echo "$VM_LIST" | jq -r ".[] | select(.name_label==\"$DC2_NAME\") | .id")
if [ -n "$UUID2" ]; then
    echo "🚀 Starting $DC2_NAME (UUID: $UUID2)..."
    $XO_CLI rest post vms/"$UUID2"/actions/start
else
    echo "⚠️ VM '$DC2_NAME' not found in XO. Skipping."
fi

echo "✅ ADDS Domain Controller startup completed."
echo "📝 Log file saved to $LOG_FILE"

