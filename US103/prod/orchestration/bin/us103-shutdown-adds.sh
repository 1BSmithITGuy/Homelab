#!/bin/bash
#----------------------------------------------------------------------------------------------------------------
#  Bryan Smith
#  BSmithITGuy@gmail.com
#  Last Update:  08/02/2025
#
#  DESCRIPTION:
#    Shuts down AD domain controllers and optional stack VMs for US103 using xo-cli and vars files.
#
#  PREREQUISITES:
#    - Domain controllers listed in vars/global/US103-AD-DCs.vars
#    - Optional VMs listed in vars/optional/us103-start-adds.vars
#    - Requires: us103-shutdown-xo-vm.sh
#----------------------------------------------------------------------------------------------------------------


set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

LIBEXEC="${REPO_ROOT}/libexec"
GLOBAL_VARS="${REPO_ROOT}/vars/global/US103-AD-DCs.vars"
OPTIONAL_VARS="${REPO_ROOT}/vars/optional/us103-start-adds.vars"

SHUTDOWN_SCRIPT="${LIBEXEC}/us103-shutdown-xo-vm.sh"

# --- Step 1: Shutdown optional stack VMs if file exists ---
if [[ -f "$OPTIONAL_VARS" ]]; then
    echo "[INFO] Shutting down optional VMs from $OPTIONAL_VARS"
    mapfile -t OPTIONAL_VMS < <(grep -vE '^\s*#' "$OPTIONAL_VARS" | grep -vE '^\s*$')
    for vm in "${OPTIONAL_VMS[@]}"; do
        echo "[INFO] Shutting down optional VM: $vm"
        "$SHUTDOWN_SCRIPT" "$vm"
    done
else
    echo "[INFO] No optional VMs to shut down (file not found: $OPTIONAL_VARS)"
fi

# --- Step 2: Shutdown AD DCs from global vars file ---
if [[ -f "$GLOBAL_VARS" ]]; then
    echo "[INFO] Shutting down AD Domain Controllers from $GLOBAL_VARS"
    mapfile -t DC_NAMES < <(grep -vE '^\s*#' "$GLOBAL_VARS" | grep -vE '^\s*$' | cut -d= -f1)
    for dc in "${DC_NAMES[@]}"; do
        echo "[INFO] Shutting down AD DC: $dc"
        "$SHUTDOWN_SCRIPT" "$dc"
    done
else
    echo "[ERROR] AD DC list not found: $GLOBAL_VARS" >&2
    exit 1
fi

