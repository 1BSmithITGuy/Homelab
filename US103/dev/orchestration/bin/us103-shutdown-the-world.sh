#!/bin/bash
#
# Cleanly shut down the entire US103 lab environment
# Shuts down K8s and AD, then cleanly shuts down hosts if possible

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"
BIN_DIR="$REPO_ROOT/bin"
LIBEXEC_DIR="$REPO_ROOT/libexec"
WORK_DIR="$REPO_ROOT/working"
mkdir -p "$WORK_DIR"

echo "🌍 Starting full lab shutdown (US103)..."

# Step 1: Shutdown core services
echo "🔧 Shutting down Kubernetes and Active Directory..."
"$BIN_DIR/us103-shutdown-k8s.sh" > "$WORK_DIR/k8s_shutdown.log" 2>&1 &
PID_K8S=$!
"$BIN_DIR/us103-shutdown-adds.sh" > "$WORK_DIR/adds_shutdown.log" 2>&1 &
PID_ADDS=$!

wait $PID_K8S
echo "✅ Kubernetes shutdown complete."
wait $PID_ADDS
echo "✅ AD shutdown complete."

# Step 2: Parse which VMs were asked to shut down from log
declare -A SHUTDOWN_REQUESTED
grep -hE "Attempting shutdown of additional VM:|Shutting down optional VM:|Shutting down AD DC:" "$WORK_DIR"/*.log | while read -r line; do
    vm=$(echo "$line" | awk -F: '{print $NF}' | xargs | tr '[:upper:]' '[:lower:]')
    SHUTDOWN_REQUESTED["$vm"]=1
done

# Step 3: Pull latest object state
echo "📡 Querying XO for current hosts and VMs..."
HOSTS_FILE="$WORK_DIR/hosts.txt"
VM_LIST_FILE="$WORK_DIR/all-vms.json"
xo-cli list-objects type=host > "$WORK_DIR/hosts.json"
xo-cli list-objects type=VM > "$VM_LIST_FILE"

jq -r '
  .[] | select(
    (.tags // [] | index("Env=Lab")) and
    (.tags // [] | index("Shutdown=Auto"))
  ) | "\(.uuid)\t\(.name_label)"
' "$WORK_DIR/hosts.json" > "$HOSTS_FILE"

# Step 4: Main host loop
while IFS=$'\t' read -r host_uuid host_name; do
  echo -e "\n🖥️ Evaluating host: $host_name ($host_uuid)"
  VM_OUTPUT=$(jq -r --arg host "$host_uuid" '
    .[] | select(
      .power_state == "Running" and
      (."$container" == $host)
    )
    | "\(.name_label)\t\(.uuid)\t\(.tags | join(","))"
  ' "$VM_LIST_FILE")

  VMS_TO_SHUTDOWN=()
  NON_AUTO_VMS=()

  while IFS=$'\t' read -r name uuid tags; do
    norm_name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    if [[ "$tags" == *"Shutdown=Auto"* ]]; then
      VMS_TO_SHUTDOWN+=("$name")
    elif [[ "${SHUTDOWN_REQUESTED[$norm_name]+found}" ]]; then
      echo "⏳ Waiting for VM '$name' (shutdown previously requested)..."
      for i in {1..10}; do
        state=$(xo-cli list-objects type=VM | jq -r --arg name "$name" '
          .[] | select(.name_label == $name) | .power_state
        ')
        if [[ "$state" != "Running" ]]; then
          echo "✅ $name is now off"
          break
        fi
        echo "⏳ Still running: $name ... retry $i"
        sleep 5
      done
      # Check one last time
      state=$(xo-cli list-objects type=VM | jq -r --arg name "$name" '
        .[] | select(.name_label == $name) | .power_state
      ')
      if [[ "$state" == "Running" ]]; then
        NON_AUTO_VMS+=("$name")
      fi
    else
      NON_AUTO_VMS+=("$name")
    fi
  done <<< "$VM_OUTPUT"

  # Shutdown VMs with Shutdown=Auto
  if [[ ${#VMS_TO_SHUTDOWN[@]} -gt 0 ]]; then
    echo "📦 Shutting down ${#VMS_TO_SHUTDOWN[@]} VMs tagged Shutdown=Auto on $host_name..."
    for vm in "${VMS_TO_SHUTDOWN[@]}"; do
      echo "🛑 Shutdown request: $vm"
      "$LIBEXEC_DIR/us103-shutdown-xo-vm.sh" "$vm"
    done
  fi

  # Host can only be shut down if all other VMs are gone
  if [[ ${#NON_AUTO_VMS[@]} -gt 0 ]]; then
    echo "⚠️ Host $host_name has VMs not tagged Shutdown=Auto (or still shutting down):"
    for vm in "${NON_AUTO_VMS[@]}"; do
      echo "    ⛔ $vm"
    done
    echo "🛑 Skipping shutdown of host $host_name"
    continue
  fi

  echo "✅ All safe — shutting down host: $host_name"
  ssh root@"$host_name" "shutdown -h now" || echo "❌ SSH failed to shutdown host: $host_name"

done < "$HOSTS_FILE"

echo -e "\n🌌 Full shutdown completed."

