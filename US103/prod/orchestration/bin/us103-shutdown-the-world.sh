#!/bin/bash
#----------------------------------------------------------------------------------------------------------------
#  Bryan Smith
#  BSmithITGuy@gmail.com
#  Last Update:  08/01/2025
#
#  DESCRIPTION:
#    Shuts down the entire US103 lab cleanly by:
#      - Shutting down Kubernetes cluster (if available)
#      - Shutting down Active Directory domain controllers
#      - Shutting down VMs tagged 'Shutdown=Auto'
#      - Shutting down hosts tagged 'Env=Lab' and 'Shutdown=Auto', only if safe
#
#  PREREQUISITES:
#    Xen Orchestra (XO) must have the following tags on hosts/VMs:
#      - Env=Lab            → Marks eligible lab hosts for shutdown
#      - Shutdown=Auto      → VM will be gracefully shut down by this script
#      - Shutdown=Host      → VM may remain running without blocking host shutdown (e.g. this script is running on it)
#
#    The following scripts must exist and be executable in the environment:
#      - /bin/us103-shutdown-k8s.sh         → Cordon/drain and shut down K8s cluster nodes
#      - /bin/us103-shutdown-adds.sh        → Shutdown Active Directory domain controllers
#      - /libexec/us103-shutdown-xo-vm.sh   → Issues graceful shutdown of VMs via SSH + xe
#
#----------------------------------------------------------------------------------------------------------------

set -euo pipefail
#  Directories:
    SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
    SCRIPT_NAME="$(basename "$SCRIPT_PATH")"
    WORK_DIR="/srv/tmp/${SCRIPT_NAME%.*}"
    mkdir -p "$WORK_DIR"

    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"
    BIN_DIR="$REPO_ROOT/bin"
    LIBEXEC_DIR="$REPO_ROOT/libexec"

echo "🌍 Starting full lab shutdown: $SCRIPT_NAME"

# Step 1: Shutdown Kubernetes (if reachable)
    echo "🔧 Attempting to shut down Kubernetes cluster..."
    
    if kubectl version --request-timeout=5s &>/dev/null; then
      "$BIN_DIR/us103-shutdown-k8s.sh" > "$WORK_DIR/k8s_shutdown.log" 2>&1 &
      PID_K8S=$!
    
        else
          echo "⚠️ Kubernetes not reachable. Skipping."
          PID_K8S=""
    fi

# Step 2: Shutdown Active Directory
    echo "🔧 Shutting down AD services..."
    
    "$BIN_DIR/us103-shutdown-adds.sh" > "$WORK_DIR/adds_shutdown.log" 2>&1 &
    PID_ADDS=$!

    [[ -n "${PID_K8S:-}" ]] && wait $PID_K8S && echo "✅ K8s shutdown done."
    wait $PID_ADDS && echo "✅ AD shutdown done."

# Step 3: Track previously requested shutdowns
    declare -A SHUTDOWN_REQUESTED
    grep -hE "Attempting shutdown of additional VM:|Shutting down optional VM:|Shutting down AD DC:" "$WORK_DIR"/*.log | while read -r line; do
      vm=$(echo "$line" | awk -F: '{print $NF}' | xargs | tr '[:upper:]' '[:lower:]')
      SHUTDOWN_REQUESTED["$vm"]=1
    done

# Step 4: Query all host and VM data
    xo-cli list-objects type=host > "$WORK_DIR/hosts.json"
    xo-cli list-objects type=VM > "$WORK_DIR/vms.json"

    jq -r '
      .[] | select(
        (.tags // [] | index("Env=Lab")) and
        (.tags // [] | index("Shutdown=Auto"))
      ) | "\(.uuid)\t\(.name_label)"
    ' "$WORK_DIR/hosts.json" > "$WORK_DIR/hosts.txt"

# Step 5: Loop through hosts
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
        elif [[ "$tags" == *"Shutdown=Host"* ]]; then
          echo "🟡 $name is tagged Shutdown=Host — allowed to stay running"
          continue
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

  # Shutdown eligible VMs
      if [[ ${#VMS_TO_SHUTDOWN[@]} -gt 0 ]]; then
        echo "📦 Shutting down ${#VMS_TO_SHUTDOWN[@]} auto-tagged VMs..."
        for vm in "${VMS_TO_SHUTDOWN[@]}"; do
          echo "🛑 Issuing shutdown for $vm"
          "$LIBEXEC_DIR/us103-shutdown-xo-vm.sh" "$vm"
        done
      fi

  # Decide whether to shut down host
      if [[ ${#NON_AUTO_VMS[@]} -gt 0 ]]; then
        echo "⚠️ Host $host_name has VMs blocking shutdown:"
        for vm in "${NON_AUTO_VMS[@]}"; do
          echo "    ⛔ $vm"
        done
        echo "🛑 Skipping host shutdown: $host_name"
        continue
      fi

  echo "🧯 Safe to shut down host: $host_name"
  ssh root@"$host_name" "shutdown -h now" || echo "❌ SSH failed: $host_name"

done < "$WORK_DIR/hosts.txt"

echo -e "\n✅ ✅ Lab shutdown complete."

