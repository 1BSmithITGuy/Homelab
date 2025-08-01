#!/bin/bash
#
# Cleanly shut down the entire US103 lab environment
# - K8s and AD shutdown in parallel
# - Host shutdown based on tags and VM tag filtering

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

BIN_DIR="$REPO_ROOT/bin"
LIBEXEC_DIR="$REPO_ROOT/libexec"
WORK_DIR="$REPO_ROOT/working"
mkdir -p "$WORK_DIR"

echo "🌍 Initiating global lab shutdown (US103)..."

# Step 1: Shutdown ADDC and K8s in parallel
echo "🚦 Starting shutdown of Kubernetes and AD services..."
"$BIN_DIR/us103-shutdown-k8s.sh" > "$WORK_DIR/k8s_shutdown.log" 2>&1 &
PID_K8S=$!
"$BIN_DIR/us103-shutdown-adds.sh" > "$WORK_DIR/adds_shutdown.log" 2>&1 &
PID_ADDS=$!

wait $PID_K8S
echo "✅ Kubernetes cluster shutdown completed."
wait $PID_ADDS
echo "✅ AD shutdown completed."

# Step 2: Gather hosts with Env=Lab and Shutdown=Auto
echo "🔍 Fetching hosts tagged Env=Lab and Shutdown=Auto..."
HOSTS_FILE="$WORK_DIR/hosts.txt"
VM_LIST_FILE="$WORK_DIR/all-vms.json"
xo-cli list-objects type=host | jq -r '
  .[] | select(
    (.tags // [] | index("Env=Lab"))
    and (.tags // [] | index("Shutdown=Auto"))
  )
  | "\(.uuid)\t\(.name_label)"
' > "$HOSTS_FILE"

if [[ ! -s "$HOSTS_FILE" ]]; then
  echo "❌ No hosts matched Env=Lab and Shutdown=Auto. Aborting host shutdown."
  exit 0
fi

xo-cli list-objects type=VM > "$VM_LIST_FILE"

# Step 3: Evaluate VMs per host and shutdown if safe
while IFS=$'\t' read -r host_uuid host_name; do
  echo -e "\n🖥️ Evaluating host: $host_name ($host_uuid)"

  # Get VMs on this host that are running
  VM_OUTPUT=$(jq -r --arg host "$host_uuid" '
    .[] | select(
      .power_state == "Running"
      and (."$container" == $host)
    )
    | "\(.name_label)\t\(.uuid)\t\(.tags | join(","))"
  ' "$VM_LIST_FILE")

  VMS_TO_SHUTDOWN=()
  NON_AUTO_VMS=()

  while IFS=$'\t' read -r name uuid tags; do
    if [[ "$tags" == *"Shutdown=Auto"* ]]; then
      VMS_TO_SHUTDOWN+=("$name")
    else
      NON_AUTO_VMS+=("$name")
    fi
  done <<< "$VM_OUTPUT"

  if [[ ${#NON_AUTO_VMS[@]} -gt 0 ]]; then
    echo "⚠️ Host $host_name has VMs not tagged Shutdown=Auto:"
    for vm in "${NON_AUTO_VMS[@]}"; do
      echo "    ⛔ $vm"
    done
    echo "🛑 Skipping shutdown of host $host_name."
    continue
  fi

  echo "📦 Shutting down ${#VMS_TO_SHUTDOWN[@]} auto-tagged VMs on $host_name..."
  for vm in "${VMS_TO_SHUTDOWN[@]}"; do
    "$LIBEXEC_DIR/us103-shutdown-xo-vm.sh" "$vm"
  done

  echo "🧯 Issuing host shutdown: $host_name"
  ssh root@"$host_name" "shutdown -h now" || echo "❗ SSH shutdown failed for host $host_name"

done < "$HOSTS_FILE"

echo "✅ ✅ ✅ Lab shutdown complete. 🌌"

