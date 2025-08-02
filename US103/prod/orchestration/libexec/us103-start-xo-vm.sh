#!/bin/bash
#----------------------------------------------------------------------------------------------------------------
#  Bryan Smith
#  BSmithITGuy@gmail.com
#  Last Update:  08/02/2025
#
#  DESCRIPTION:
#    Starts one or more VMs by name using xo-cli and matches against case-insensitive names.
#
#  PREREQUISITES:
#    - Requires working xo-cli
#    - VM must exist in the XO object cache
#    - Used by startup scripts
#    - SSH keys and xo-cli login configured
#
#  USAGE:  ./us103-start-xo-vm VM_NAME [VM_NAME ...]
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

