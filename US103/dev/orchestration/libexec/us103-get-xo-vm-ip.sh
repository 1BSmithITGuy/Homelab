#!/bin/bash
#
# Simple script to get a VM's IP address using xo-cli and jq
# Usage: ./get-vm-ip.sh <vm_name>

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <vm_name>"
    exit 1
fi

vm_name="$1"

get_vm_ip() {
    local vm_data
    vm_data=$(xo-cli list-objects type=VM | jq --arg name "$vm_name" '.[] | select(.name_label == $name)')
    if [[ -z "$vm_data" ]]; then
        echo "VM '$vm_name' not found"
        return 1
    fi

    echo "$vm_data" | jq -r '.addresses | to_entries[] | .value[0]' | head -n1
}

get_vm_ip
