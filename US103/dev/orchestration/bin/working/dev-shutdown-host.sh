#!/bin/bash
#
# Dev script: Cleanly shutdown VMs with Shutdown=Auto tag using XO before XO is shut down,
# then SSH into host to evaluate if it is safe to shut down based on remaining VMs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"
BIN_DIR="$REPO_ROOT/bin"
LIBEXEC_DIR="$REPO_ROOT/libexec"
WORK_DIR="$REPO_ROOT/working/dev"
mkdir -p "$WORK_DIR"

VM_JSON="$WORK_DIR/all-vms.json"
HOST_JSON="$WORK_DIR/hosts.json"

# 1. Gather VM and Host state from XO BEFORE XO VM is shut down
echo "📡 Gathering VM and host info from XO before shutdown..."
xo-cli list-objects type=VM > "$VM_JSON"
xo-cli list-objects type=host > "$HOST_JSON"

XO_VM_NAME="BSUS103XO01"
XO_HOST_UUID=$(jq -r --arg name "$XO_VM_NAME" \
  '.[] | select(.name_label | ascii_downcase == ($name | ascii_downcase)) | ."$container"' "$VM_JSON")
XO_HOST_NAME=$(jq -r --arg uuid "$XO_HOST_UUID" \
  '.[] | select(.uuid == $uuid) | .name_label' "$HOST_JSON")

if [[ -z "$XO_HOST_NAME" ]]; then
  echo "❌ Could not determine XO host name. UUID: $XO_HOST_UUID"
  exit 1
fi

# 2. Shutdown all VMs tagged Shutdown=Auto using wrapper script
echo "⚙️ Shutting down VMs tagged with Shutdown=Auto..."
jq -r '
  .[] | select((.tags // []) | index("Shutdown=Auto")) 
  | select(.power_state == "Running") 
  | .name_label
' "$VM_JSON" | while read -r vm_name; do
  echo "➡️ Shutting down VM via wrapper: $vm_name"
  "$LIBEXEC_DIR/us103-shutdown-xo-vm.sh" "$vm_name"
done

# 3. Wait for XO VM to power off by polling via SSH into host
MAX_RETRIES=12
RETRY_DELAY=10
retries=0

while true; do
  echo "⏳ Checking if XO VM is off on host $XO_HOST_NAME... (try $((retries+1))/$MAX_RETRIES)"
  XO_VM_STATE=$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@"$XO_HOST_NAME" \
    "xe vm-list name-label=$XO_VM_NAME params=power-state --minimal" 2>/dev/null || echo "")

  if [[ "$XO_VM_STATE" == "halted" ]]; then
    echo "✅ XO VM has shut down."
    break
  fi

  ((retries++))
  if [[ $retries -ge $MAX_RETRIES ]]; then
    echo "❌ XO VM did not shut down in expected time."
    exit 1
  fi
  sleep $RETRY_DELAY
done

# 4. Evaluate remaining VMs on XO host using SSH
echo "🔍 Checking host: $XO_HOST_NAME via SSH (where XO was running)..."
running_vms=$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@"$XO_HOST_NAME" \
  "xe vm-list power-state=running params=name-label | grep name-label | awk -F': ' '{print \$2}'") || {
    echo "⚠️ Could not connect to host $XO_HOST_NAME"
    exit 1
}

# Filter out control domains
user_vms=()
while read -r vm; do
  [[ "$vm" =~ Control\ domain ]] && continue
  user_vms+=("$vm")
done <<< "$running_vms"

SAFE_TO_SHUTDOWN=true
for vm in "${user_vms[@]}"; do
  tag_check=$(jq -r --arg name "$vm" '
    .[] | select(.name_label == $name) | (.tags // []) | join(",")
  ' "$VM_JSON")

  if [[ "$tag_check" != *"Shutdown=Host"* ]]; then
    echo "❌ $vm does not have Shutdown=Host tag — skipping host shutdown."
    SAFE_TO_SHUTDOWN=false
    break
  fi
done

if $SAFE_TO_SHUTDOWN; then
  echo "🛑 All remaining VMs are safe. Shutting down host $XO_HOST_NAME..."
  ssh root@"$XO_HOST_NAME" 'shutdown now' || echo "⚠️ Failed to shut down $XO_HOST_NAME"
fi

