#!/bin/bash
#
# List VMs with the tag Shutdown=Auto

set -euo pipefail

echo "🔍 Finding VMs with tag: Shutdown=Auto..."

xo-cli list-objects type=VM | jq -r '
  .[]
  | select(
      .tags // [] | index("Shutdown=Auto")
    )
  | "\(.uuid)\t\(.name_label)\t\(.power_state)\t\(.tags | join(","))"
' | column -t -s $'\t'

