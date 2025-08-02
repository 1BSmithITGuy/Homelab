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
#
#  USAGE:  
#    us103-shutdown-xo-vm.sh VM_NAME1 [VM_NAME2 ...]
#----------------------------------------------------------------------------------------------------------------

SSH_USER="root"
XCPNG_HOSTS=("10.0.0.52" "10.0.0.51")  # Primary first, fallback second

if [ $# -eq 0 ]; then
    echo "Usage: $0 VM_NAME1 [VM_NAME2 ...]" >&2
    exit 1
fi

# Function to build VM name => UUID map from a given host
get_vm_map_from_host() {
    local host="$1"
    local raw
    declare -A map
    raw=$(ssh -o BatchMode=yes "${SSH_USER}@${host}" xe vm-list power-state=running 2>/dev/null) || return 1

    local uuid="" name=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^uuid ]]; then
            uuid=$(echo "$line" | awk -F: '{print $2}' | xargs)
            name=""
        elif [[ "$line" =~ name-label ]]; then
            name=$(echo "$line" | awk -F: '{print $2}' | xargs)
        fi

        if [[ -n "$uuid" && -n "$name" ]]; then
            if [[ "$name" =~ [Cc]ontrol\ domain ]]; then
                uuid=""
                name=""
                continue
            fi
            key=$(echo "$name" | tr '[:upper:]' '[:lower:]')
            map["$key"]="$uuid|$name"
            uuid=""
            name=""
        fi
    done <<< "$raw"

    for key in "${!map[@]}"; do
        echo "$key|${map[$key]}"
    done
}

# Loop through each input VM
for VM_INPUT in "$@"; do
    found=0
    vm_key=$(echo "$VM_INPUT" | tr '[:upper:]' '[:lower:]')

    for host in "${XCPNG_HOSTS[@]}"; do
        while IFS="|" read -r key value; do
            [[ -z "$key" || -z "$value" ]] && continue
            if [[ "$key" == "$vm_key" ]]; then
                uuid="${value%%|*}"
                name="${value#*|}"
                echo "Shutting down VM '$name' (UUID: $uuid) on host $host..."
                if ssh -o BatchMode=yes "${SSH_USER}@${host}" xe vm-shutdown uuid="$uuid"; then
                    echo "SUCCESS: VM '$name' shutdown issued on $host."
                else
                    echo "ERROR: Failed to shut down VM '$name' on $host" >&2
                fi
                found=1
                break 2
            fi
        done < <(get_vm_map_from_host "$host")
    done

    if [[ $found -eq 0 ]]; then
        echo "WARNING: VM '$VM_INPUT' not found on any host." >&2
    fi
done

