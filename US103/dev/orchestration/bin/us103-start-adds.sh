#!/bin/bash
#
# Script to start Active Directory Domain Controllers (AD DCs)
# for site US103.
#
# Loads VM hostname:IP pairs from /orchestration/vars/global/US103-AD-DCs.vars
# Optionally loads /orchestration/vars/optional/us103-start-adds.sh.vars
# Starts each listed VM using libexec/us103-start-xo-vm.sh
# Attempts to restart and flush DNS services (non-fatal)

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

GLOBAL_VARS="$REPO_ROOT/vars/global/US103-AD-DCs.vars"
OPTIONAL_VARS="$REPO_ROOT/vars/optional/${SCRIPT_NAME}.vars"
START_VM_SCRIPT="$REPO_ROOT/libexec/us103-start-xo-vm.sh"

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
else
    echo "[$SCRIPT_NAME] No optional vars found."
fi

if [[ "${#AD_DC_MAP[@]}" -eq 0 ]]; then
    echo "[$SCRIPT_NAME] ERROR: No domain controllers found in $GLOBAL_VARS"
    exit 1
fi

echo "[$SCRIPT_NAME] Starting Domain Controllers..."
for vm in "${!AD_DC_MAP[@]}"; do
    ip="${AD_DC_MAP[$vm]}"
    echo "[$SCRIPT_NAME] Starting VM: $vm (IP: $ip)"
    "$START_VM_SCRIPT" "$vm"
done


echo "[$SCRIPT_NAME] All done."

