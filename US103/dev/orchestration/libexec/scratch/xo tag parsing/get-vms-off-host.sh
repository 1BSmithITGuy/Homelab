#!/bin/bash
#
# Scan live VM data from xo-cli and find matches by host UUID and tags

set -euo pipefail

TARGET_HOST_UUID="fdae1ebb-b2de-4051-9fac-57a1e11738e0"

echo "🔍 Running xo-cli and scanning for matching VMs on host $TARGET_HOST_UUID..."

xo-cli list-objects type=VM | jq -r --arg host "$TARGET_HOST_UUID" '
  .[]
  | select(
      .power_state == "Running"
      and (."$container" == $host)
      and (.tags // [] | index("Shutdown=Auto"))
      and (.tags // [] | index("Env=Lab"))
    )
  | "✅ \(.name_label)\t\(.uuid)"
'

