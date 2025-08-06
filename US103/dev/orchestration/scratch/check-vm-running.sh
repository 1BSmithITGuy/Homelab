#!/bin/bash
# Usage: ./check-vm-running.sh <vm_name> <host_name>
vm="$1"
host="$2"

echo "🔍 Checking if VM '$vm' is running on host '$host'..."
result=$(ssh root@"$host" "xe vm-list name-label=\"$vm\" power-state=running --minimal")
if [[ -z "$result" ]]; then
  echo "✅ $vm is NOT running."
else
  echo "❗ $vm is STILL running."
fi

