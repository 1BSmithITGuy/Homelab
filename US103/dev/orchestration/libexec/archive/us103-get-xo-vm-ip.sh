#!/bin/bash
#
# Get a VM's IP address using xo-cli and jq (case-insensitive)
# Falls back to mainIpAddress if .addresses is empty
# Usage: ./us103-get-xo-vm-ip.sh <vm_name>

set -euo pipefail

DEBUG=false

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <vm_name>"
    exit 1
fi

input_vm_name="$1"
search_name=$(echo "$input_vm_name" | tr '[:upper:]' '[:lower:]')

vm_data=$(xo-cli list-objects type=VM | jq --arg name "$search_name" '
  .[] | select(.name_label? | ascii_downcase == $name)
')

if [[ -z "$vm_data" || "$vm_data" == "null" ]]; then
    echo "❌ VM '$input_vm_name' not found"
    exit 1
fi

$DEBUG && echo "DEBUG: Full VM JSON:" && echo "$vm_data" | jq

# Try extracting first IPv4 address from .addresses
ip=$(echo "$vm_data" | jq -r '
  if (.addresses | type == "object" and (.addresses | length > 0)) then
    .addresses | to_entries[]
    | .value
    | select(test("^([0-9]{1,3}\\.){3}[0-9]{1,3}$"))
  else
    empty
  end' | head -n 1)

# Fallback to mainIpAddress if .addresses is empty
if [[ -z "$ip" ]]; then
    ip=$(echo "$vm_data" | jq -r '.mainIpAddress // empty')
fi

if [[ -z "$ip" ]]; then
    echo "⚠️ No IP address found for '$input_vm_name'"
    exit 2
fi

echo "$ip"

