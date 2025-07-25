#!/bin/bash
#
# Shuts down Active Directory Domain Controllers for US103.
#
# Loads:
#   - /orchestration/vars/global/US103-AD-DCs.vars
#   - Optional: /orchestration/vars/optional/us103-shutdown-adds.sh.vars
# Calls:
#   - /orchestration/libexec/us103-shutdown-xo-vm.sh

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

GLOBAL_VARS="$REPO_ROOT/vars/global/US103-AD-DCs.vars"
OPTIONAL_VARS="$REPO_ROOT/vars/optional/${SCRIPT_NAME}.vars"
SHUTDOWN_VM_SCRIPT="$REPO_ROOT/libexec/us103-shutdown-xo-vm.sh"

declare -A AD_DC_MAP

echo "[$SCRIPT_NAME] Loading global vars: $GLOBAL_VARS"
while IFS='=' read -r vm ip; do
    [[ -z "$vm" || "$vm" =~ ^# ]] && continue
    AD_DC_MAP["$vm"]="$ip"
done < "$GLOBAL_VARS"

if [[ -f "$OPTIONAL_VARS" ]]; then
    echo "[$SCRIPT_NAME] Loading optional vars: $OPTIONAL_VARS"
    # shellcheck source=/dev/null
    source "$OPTIONAL_VARS"
fi

VM_LIST=("${!AD_DC_MAP[@]}")
if [[ "${#VM_LIST[@]}" -eq 0 ]]; then
    echo "[$SCRIPT_NAME] ERROR: No VMs to shut down"
    exit 1
fi

echo "[$SCRIPT_NAME] Shutting down Domain Controllers: ${VM_LIST[*]}"
"$SHUTDOWN_VM_SCRIPT" "${VM_LIST[@]}"
