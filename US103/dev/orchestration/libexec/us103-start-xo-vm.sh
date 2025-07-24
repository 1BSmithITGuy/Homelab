#----------------------------------------------------------------------------------------------------------------
#  Bryan Smith
#  BSmithITGuy@gmail.com
#  Last Update:  07/23/2025

#  DESCRIPTION:
    #  Shared helper script to start one or more VMs using xo-cli.
    #  Usage: ./us103-start-xo-vm VM_NAME [VM_NAME ...]

#  PREREQUISITES
    #   This script is intended to be run on an Ubuntu jump station that has xo-cli and SSH keys to the XCP-NG hosts setup
      #   See jump station readme.md for instructions

#----------------------------------------------------------------------------------------------------------------

set -euo pipefail

XO_CLI=$(which xo-cli)

if [ $# -eq 0 ]; then
    echo "❌ Error: No VM names provided."
    echo "Usage: $0 VM_NAME [VM_NAME ...]"
    exit 1
fi

echo "📦 Starting VMs using xo-cli..."

# Fetch list of all VMs once
VM_LIST=$($XO_CLI list-objects type=VM)

# Loop through input VM names
for VM_NAME in "$@"; do
    UUID=$(echo "$VM_LIST" | jq -r ".[] | select(.name_label==\"$VM_NAME\") | .id")
    if [ -n "$UUID" ]; then
        echo "🚀 Starting $VM_NAME (UUID: $UUID)..."
        $XO_CLI rest post vms/"$UUID"/actions/start
    else
        echo "⚠️ VM '$VM_NAME' not found in xo-cli output."
    fi
done

echo "✅ VM startup complete."
