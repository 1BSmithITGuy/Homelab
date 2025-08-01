#!/bin/bash
#
# Cleanly shut down the entire US103 lab environment
# - Shuts down Kubernetes & AD
# - Gracefully powers off Shutdown=Auto VMs
# - Shuts down hosts if no non-auto VMs are left running

set -euo pipefail

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"
WORK_DIR="/srv/tmp/${SCRIPT_NAME%.*}"
mkdir -p "$WORK_DIR"

SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"
BIN_DIR="$REPO_ROOT/bin"
LIBEXEC_DIR="$REPO_ROOT/libexec"

echo "🌍 Starting full lab shutdown ($SCRIPT_NAME)..."

# Step 1: Shutdown core services (K8s and AD)
echo "🔧 Attempting to shut down Kubernetes cluster..."
if kubectl version --request-timeout=5s &>/dev/null; then
  "$BIN_DIR/us103-shutdown-k8s.sh" > "$WORK_DIR/k8s_shutdown.log" 2>&1 &
  PID_K8S=$!
else
  echo "⚠️ Kubernetes not accessible. Skipping us103-shutdown-k8s.sh"
  PID_K8S=""
fi

echo "🔧 Shutting down AD services..."
"$BIN_DIR/us103-shutdown-adds.sh" > "$WORK_DIR/adds_shutdown.log" 2>&1 &
PID_ADDS=$!

[[ -n "$PID_K8S" ]] && wait $PID_K8S && echo "✅ Kubernetes shutdown complete."
wait $PID_ADDS && echo "✅ AD shutdown complete."

# Step 2: Track VMs we attempted to shut down earlier (optional/known delay)
declare -A SHUTDOWN_REQUESTED
grep -hE "Attempting shutdown of additional VM:|Shutting down optional VM:|Shutting down AD DC:" "$WORK_DIR"/*.log | while read -r line; do
  vm=$(echo "$line" | awk -F: '{print $NF}' | xargs | tr '[:upper:]' '[:lower:]')
  SHUTDOWN_REQUESTED["$vm"]=1
done

# Step 3: Pull latest VM and host data
xo-cli list-objects type=host > "$WORK_DIR/hosts.json"
xo-cli list-objects type=VM > "$WORK_DIR/vms.json"

jq -r '
  .[] | select(
    (.tags // [] | index("Env=Lab")) and
    (.tags // [] | index("Shutdown=Auto"))
  ) | "\(.uuid)\t\(.name_label)"
' "$WORK_DIR/hosts.json" > "$WORK_DIR/hosts.txt"

# Step 4: Process each host
while IFS=$'\t' read -r host_uuid host_name; do
  echo -e "\n🖥️ Evaluating host: $host_name ($host_uuid)"
  VM_OUTPUT=$(jq -r --arg host "$host_uuid" '
    .[] | select(
      .power_state == "Running" and
      (."$container" == $host)
    )
    | "\(.name_label)\t\(.uuid)\t\(.tags | join(","))"
  ' "$WORK_DIR/vms.json")

  VMS_TO_SHUTDOWN=()
  NON_AUTO_VMS=()

  while IFS=$'\t' read -r name uuid tags; do
    norm_name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    if [[ "$tags" == *"Shutdown=Auto"* ]]; then
      VMS_TO_SHUTDOWN+=("$name")
    elif [[ "${SHUTDOWN_REQUESTED[$norm_name]+_}" ]]; then
      echo "⏳ Waiting for $name to shut down..."
      for i in {1..6}; do
        state=$(xo-cli list-objects type=VM | jq -r --arg name "$name" '
          .[] | select(.name_label == $name) | .power_state
        ')
        [[ "$state" != "Running" ]] && break
        sleep 5
      done
      [[ "$state" == "Running" ]] && NON_AUTO_VMS+=("$name")
    else
      NON_AUTO_VMS+=("$name")
    fi
  done <<< "$VM_OUTPUT"

  # Shutdown tagged VMs
  if [[ ${#VMS_TO_SHUTDOWN[@]} -gt 0 ]]; then
    echo "📦 Shutting down ${#VMS_TO_SHUTDOWN[@]} auto-tagged VMs on $host_name..."
    for vm in "${VMS_TO_SHUTDOWN[@]}"; do
      echo "🛑 Shutting down $vm"
      "$LIBEXEC_DIR/us103-shutdown-xo-vm.sh" "$vm"
    done
  fi

  # Shutdown host only if no unapproved VMs remain
  if [[ ${#NON_AUTO_VMS[@]} -gt 0 ]]; then
    echo "⚠️ Host $host_name has VMs that are not Shutdown=Auto:"
    for vm in "${NON_AUTO_VMS[@]}"; do
      echo "    ⛔ $vm"
    done
    echo "🛑 Skipping host shutdown: $host_name"
    continue
  fi

  echo "🧯 Safe to shut down host: $host_name"
  ssh root@"$host_name" "shutdown -h now" || echo "❌ SSH failed to shut down $host_name"

done < "$WORK_DIR/hosts.txt"

echo -e "\n✅ Global shutdown complete."

