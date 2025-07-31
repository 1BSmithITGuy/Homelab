#!/bin/bash
#----------------------------------------------------------------------------------------------------------------
#  Bryan Smith
#  BSmithITGuy@gmail.com
#  Last Update:  07/25/2025
#
#  DESCRIPTION:
#    Shared helper script to start one or more VMs using xo-cli.
#    Usage: ./us103-start-xo-vm VM_NAME [VM_NAME ...]
#
#  PREREQUISITES:
#    - Run on Ubuntu jump station with xo-cli installed
#    - SSH access and xo-cli login configured
#----------------------------------------------------------------------------------------------------------------

set -euo pipefail

XO_CLI=$(which xo-cli)

if [ $# -eq 0 ]; then
    echo "❌ Error: No VM names provided."
    echo "Usage: $0 VM_NAME [VM_NAME ...]"
    exit 1
fi

echo "📦 Starting VMs using xo-cli..."

# Fetch all VM objects once
VM_LIST=$($XO_CLI list-objects type=VM)

for VM_NAME in "$@"; do
    echo "➡️  Starting VM: $VM_NAME"

    # Perform case-insensitive match
    UUID=$(echo "$VM_LIST" | jq -r --arg name_lc "$(echo "$VM_NAME" | tr '[:upper:]' '[:lower:]')" \
        '.[] | select(.name_label and (.name_label | ascii_downcase) == $name_lc) | .id')

    if [[ -n "$UUID" ]]; then
        echo "🚀 Starting $VM_NAME (UUID: $UUID)..."
        $XO_CLI rest post vms/"$UUID"/actions/start
    else
        echo "⚠️  VM '$VM_NAME' not found (case-insensitive match)"
    fi
done

echo "✅ VM startup complete."

