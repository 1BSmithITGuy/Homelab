#!/bin/bash
#
# Retrieves all objects with their tags using xo-cli
# Requires: xo-cli and jq
# Usage: ./get-xo-objects-with-tags.sh

set -euo pipefail

echo "🔍 Retrieving objects with tags from Xen Orchestra..."

# Get all objects
objects=$(xo-cli list-objects)

# Filter and print object name, type, and tags (if any)
echo -e "TYPE\tNAME\tTAGS"

echo "$objects" | jq -r '
  .[]
  | select(.tags != null and (.tags | length > 0))
  | "\(.type)\t\(.name_label // .name_description // "N/A")\t\(.tags | join(","))"
'

