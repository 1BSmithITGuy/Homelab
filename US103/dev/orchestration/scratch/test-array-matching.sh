#!/bin/bash
# Simulate what us103-shutdown-the-world.sh is doing

declare -A SHUTDOWN_REQUESTED

# Add shutdown-triggered VMs (normally from logs)
for vm in "bsus103k-8m01" "INFUS103DC01"; do
  SHUTDOWN_REQUESTED["$vm"]=1
done

# Simulate a VM name found from xo-cli or xe
vm_to_check="bsus103k-8m01"
#vm_to_check="BSUS103K-8M01"   # Uncomment to test mismatch

if [[ "${SHUTDOWN_REQUESTED[$vm_to_check]+_}" ]]; then
  echo "✅ Match found for: $vm_to_check"
else
  echo "❌ No match for: $vm_to_check"
fi

