#!/bin/bash
#
# List hosts with both Env=Lab and Shutdown=Auto tags

set -euo pipefail

echo "🔍 Finding hosts with tags: Env=Lab AND Shutdown=Auto..."

xo-cli list-objects type=host | jq -r '
  .[]
  | select(
      (.tags // [] | index("Env=Lab"))
      and (.tags // [] | index("Shutdown=Auto"))
    )
  | "\(.uuid)\t\(.name_label)\t\(.tags | join(","))"
' | column -t -s $'\t'

