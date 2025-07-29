#!/usr/bin/env bash

# us103-start-k8s.sh
# Starts Kubernetes cluster VMs listed in a vars file and uncordons nodes once ready.

set -euo pipefail

# Paths
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARS_DIR="$SCRIPT_DIR/../vars"
AD_VARS="$VARS_DIR/global/US103-AD-DCs.vars"
GLOBAL_VARS="$VARS_DIR/global/US103-k8s-servers.vars"
OPTIONAL_VARS="$VARS_DIR/optional/${SCRIPT_NAME%.sh}.vars"
START_VM_SCRIPT="$SCRIPT_DIR/../libexec/us103-start-xo-vm.sh"
START_ADDS_SCRIPT="$SCRIPT_DIR/us103-start-adds.sh"

# Validate vars files
for file in "$GLOBAL_VARS" "$AD_VARS"; do
  if [[ ! -f "$file" ]]; then
    echo "❌ Missing required file: $file" >&2
    exit 1
  fi
done

# Parse context (case-insensitive)
context=$(grep -iE '^[[:space:]]*context=' "$GLOBAL_VARS" | head -n1 | cut -d= -f2-)
if [[ -z "$context" ]]; then
  echo "❌ 'context=' not found in $GLOBAL_VARS" >&2
  exit 1
fi

# Parse nodes (case-insensitive, comma-separated)
nodes_line=$(grep -iE '^[[:space:]]*nodes=' "$GLOBAL_VARS" | head -n1 | cut -d= -f2-)
if [[ -z "$nodes_line" ]]; then
  echo "❌ 'nodes=' not found in $GLOBAL_VARS" >&2
  exit 1
fi
IFS=, read -r -a nodes <<< "$nodes_line"

# Function: check DNS port 53
dns_up() {
  while IFS='=' read -r vm ip; do
    [[ "$vm" =~ ^#.*$ || -z "$vm" ]] && continue
    if timeout 1 bash -c "</dev/tcp/$ip/53" &>/dev/null; then
      return 0
    fi
  done < "$AD_VARS"
  return 1
}

# Ensure DNS is reachable or start AD/DC VMs
echo "🔍 Checking DNS reachability..."
if ! dns_up; then
  echo "🚨 DNS unreachable. Starting AD/DC servers..."
  "$START_ADDS_SCRIPT"
  echo "⏳ Waiting for DNS..."
  until dns_up; do sleep 5; done
  echo "✅ DNS is now reachable"
fi

# Start Kubernetes VMs
echo "📦 Starting Kubernetes VMs for context: $context"
for vm in "${nodes[@]}"; do
  echo "➡️ Starting VM: $vm"
  "$START_VM_SCRIPT" "$vm"
done

# Switch kubectl context
echo "🔄 Switching kubectl to context '$context'..."
kubectl config use-context "$context"

# Wait for API server
echo "⏳ Waiting for Kubernetes API server..."
for i in {1..20}; do
  if kubectl cluster-info >/dev/null 2>&1; then
    echo "✅ API server is available"
    break
  fi
  echo "🔄 API server not ready, retrying..."
  sleep 5
done

# Wait for nodes to become Ready or Ready,SchedulingDisabled
echo "⏳ Waiting for all nodes to be Ready..."
for i in {1..20}; do
  all_ready=true
  for vm in "${nodes[@]}"; do
    status=$(kubectl get node "$vm" --no-headers 2>/dev/null | awk '{print $2}') || status=""
    if [[ ! "$status" =~ ^Ready ]]; then
      echo "  - $vm: ${status:-Unknown}"
      all_ready=false
    fi
  done
  if [[ "$all_ready" == "true" ]]; then
    echo "✅ All nodes Ready (or Ready,SchedulingDisabled)"
    break
  fi
  sleep 5
done

# Uncordon any cordoned nodes
echo "🔓 Uncordoning nodes if needed..."
for vm in "${nodes[@]}"; do
  cordoned=$(kubectl get node "$vm" -o jsonpath='{.spec.unschedulable}' 2>/dev/null || echo "false")
  if [[ "$cordoned" == "true" ]]; then
    echo "🔓 Uncordoning $vm"
    kubectl uncordon "$vm"
  fi
done

# Start optional standalone VMs (one VM per line, ignore comments)
if [[ -f "$OPTIONAL_VARS" ]]; then
  echo "📦 Starting optional VMs from $OPTIONAL_VARS"
  # Read non-comment, non-empty lines
  mapfile -t optional_vms < <(grep -vE '^[[:space:]]*#' "$OPTIONAL_VARS" | sed '/^[[:space:]]*$/d')
  for vm in "${optional_vms[@]}"; do
    echo "➡️ Starting optional VM: $vm"
    "$START_VM_SCRIPT" "$vm"
  done
fi

echo "✅ All done."

