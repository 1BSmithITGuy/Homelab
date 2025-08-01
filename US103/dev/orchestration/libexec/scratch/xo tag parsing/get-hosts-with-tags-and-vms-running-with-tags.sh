#!/bin/bash
#
# Find all running VMs tagged Shutdown=Auto on hosts tagged Env=Lab and Shutdown=Auto

set -euo pipefail

echo "🔍 Fetching hosts tagged Env=Lab and Shutdown=Auto..."

# Step 1: Get matching host UUIDs and names
xo-cli list-objects type=host | jq -r '
  .[]
  | select(
      (.tags // [] | index("Env=Lab"))
      and (.tags // [] | index("Shutdown=Auto"))
    )
  | "\(.uuid)\t\(.name_label)"
' > /tmp/matching-hosts.txt

if [[ ! -s /tmp/matching-hosts.txt ]]; then
  echo "❌ No matching hosts found."
  exit 0
fi

echo "✅ Matching hosts:"
cat /tmp/matching-hosts.txt

# Step 2: Get all VM objects
echo -e "\n📥 Fetching VMs..."
xo-cli list-objects type=VM > /tmp/all-vms.json

echo -e "\n🔍 Filtering VMs on matching hosts with Shutdown=Auto..."

# Step 3: Loop through each host and find matching VMs
while IFS=$'\t' read -r host_uuid host_name; do
  echo -e "\n📦 Host: $host_name ($host_uuid)"
  
  jq -r --arg host "$host_uuid" '
    .[]
    | select(
        .power_state == "Running"
        and (."$container" == $host)
        and (.tags // [] | index("Shutdown=Auto"))
      )
    | "✅ \(.name_label)\t\(.uuid)\t\(.tags | join(","))"
  ' /tmp/all-vms.json

done < /tmp/matching-hosts.txt

