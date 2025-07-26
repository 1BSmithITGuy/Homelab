#!/bin/bash
#---------------------------------------------------------------------------------
#  Bryan Smith
#  BSmithITGuy@gmail.com
#  Last Update:  07/21/2025

#   DESCRIPTION:
  #  Get a VM's IPv4 address using xo-cli and jq (case-insensitive)

#   PREREQUISITES:
  #  This script is intended to be run on an Ubuntu jump station that has xo-cli installed/configured
        #   See jump station readme.md for instructions

#   USAGE:
    #   ./us103-get-xo-vm-ip.sh "<vm_name>"

#   NOTES:
  #  Only grabs the first IP.

#--------------------------------------------------------------------------------


set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <vm_name>"
    exit 1
fi

input_vm_name="$1"
search_name=$(echo "$input_vm_name" | tr '[:upper:]' '[:lower:]')

vm_data=$(xo-cli list-objects type=VM | jq --arg name "$search_name" '
  .[] | select(.name_label? | ascii_downcase == $name)
')

if [[ -z "$vm_data" ]]; then
    echo "❌ VM '$input_vm_name' not found"
    exit 1
fi

ip=$(echo "$vm_data" | jq -r '
  .addresses | to_entries[]
  | .value
  | select(test("^([0-9]{1,3}\\.){3}[0-9]{1,3}$"))
' | head -n 1)

if [[ -z "$ip" ]]; then
    echo "⚠️ No IPv4 address found for '$input_vm_name'"
    exit 2
fi

echo "$ip"

