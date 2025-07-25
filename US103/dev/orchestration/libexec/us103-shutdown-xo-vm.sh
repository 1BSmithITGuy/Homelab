#!/bin/bash
#
# Gracefully shut down one or more VMs using xo-cli.
# Usage:
#   us103-shutdown-xo-vm.sh <vm_name1> [<vm_name2> ...]
#
# Each VM will be shut down using ACPI; errors are reported but do not stop the script.

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$#" -eq 0 ]]; then
    echo "Usage: $SCRIPT_NAME <vm_name1> [<vm_name2> ...]"
    exit 1
fi

for vm_name in "$@"; do
    echo "[$SCRIPT_NAME] Attempting ACPI shutdown for VM: $vm_name"
    if xo-cli vm.shutdown name-label="$vm_name"; then
        echo "  → Successfully issued shutdown for $vm_name"
    else
        echo "  ⚠️ Failed to shut down $vm_name via xo-cli"
    fi
done
