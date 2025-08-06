#!/bin/bash
#----------------------------------------------------------------------------------------------------------------
#  Bryan Smith
#  BSmithITGuy@gmail.com
#  Last Update:  08/02/2025
#
#  DESCRIPTION:
#    Shuts down VMs and verifies they are shutdown.  
#
#  PREREQUISITES:
#    - Requires working xo-cli
#    - VM must exist in the XO object cache
#    - Used by shutdown scripts
#    - SSH keys
#  USAGE:  
#    us103-shutdown-xo-vm.sh VM_NAME1 VM_NAME2
#----------------------------------------------------------------------------------------------------------------

SCRIPT_NAME=$(basename "$0")
WORKDIR="/srv/tmp/${SCRIPT_NAME%.*}"
mkdir -p "$WORKDIR"

# Timeout settings
SHUTDOWN_TIMEOUT_SECONDS=180  # 3 minutes
CHECK_INTERVAL=1

# Track shutdown requests
declare -A VM_HOST_MAP
declare -A VM_UUID_MAP

# Step 1: Collect all VMs to shut down and trigger shutdown in background
for vm_name in "$@"; do
  echo "🚀 Initiating shutdown for VM '$vm_name'..."

  vm_data=$(xo-cli list-objects type=VM | jq -r --arg name "$vm_name" '
    .[] | select(.name_label == $name) | {id, host: .["$container"]}
  ')

  vm_uuid=$(echo "$vm_data" | jq -r '.id')
  host_id=$(echo "$vm_data" | jq -r '.host')

  if [[ -z "$vm_uuid" || -z "$host_id" || "$host_id" == "null" ]]; then
    echo "⚠️ WARNING: Could not find VM '$vm_name' or its host."
    continue
  fi

  host_ip=$(xo-cli list-objects type=host | jq -r --arg id "$host_id" '
    .[] | select(.id == $id) | .address
  ')

  if [[ -z "$host_ip" ]]; then
    echo "⚠️ WARNING: Could not resolve host IP for VM '$vm_name'."
    continue
  fi

  echo "🛑 Sending shutdown for '$vm_name' (UUID: $vm_uuid) on host $host_ip..."
  ssh root@"$host_ip" "xe vm-shutdown uuid=$vm_uuid" &
  VM_HOST_MAP["$vm_name"]="$host_ip"
  VM_UUID_MAP["$vm_name"]="$vm_uuid"
done

# Wait for background ssh shutdowns to complete
wait

# Step 2: Wait for all VMs to shut down (polling loop)
echo "⏳ Waiting up to $SHUTDOWN_TIMEOUT_SECONDS seconds for all VMs to power off..."
start_time=$(date +%s)

pending_vms=("${!VM_HOST_MAP[@]}")

while [[ ${#pending_vms[@]} -gt 0 ]]; do
  sleep $CHECK_INTERVAL
  new_pending=()

  for vm in "${pending_vms[@]}"; do
    host_ip="${VM_HOST_MAP[$vm]}"
    uuid="${VM_UUID_MAP[$vm]}"

    if ssh root@"$host_ip" "xe vm-list uuid=$uuid power-state=running --minimal" | grep -q .; then
      new_pending+=("$vm")
    else
      echo "✅ VM '$vm' is now powered off."
    fi
  done

  pending_vms=("${new_pending[@]}")

  elapsed=$(( $(date +%s) - start_time ))
  if [[ $elapsed -ge $SHUTDOWN_TIMEOUT_SECONDS ]]; then
    echo "⏱️ Timeout reached. The following VMs did not shut down:"
    for vm in "${pending_vms[@]}"; do
      echo "    ❌ $vm"
    done
    exit 1
  fi
done

echo "🎉 All VMs shut down successfully."
exit 0
