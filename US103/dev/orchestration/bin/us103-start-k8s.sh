#!/bin/bash

# us103-start-k8s.sh
# Starts Kubernetes VMs and uncordons worker nodes once the cluster is ready.
# Requires the following directory structure:
#   - ../vars/global/US103-k8s-servers.vars
#   - ../vars/optional/<scriptname>.vars (optional)
#   - ../libexec/us103-start-xo-vm.sh (must exist and work)

set -eo pipefail

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARS_DIR="$SCRIPT_DIR/../vars"
LIBEXEC_DIR="$SCRIPT_DIR/../libexec"
GLOBAL_VARS_FILE="$VARS_DIR/global/US103-k8s-servers.vars"
OPTIONAL_VARS_FILE="$VARS_DIR/optional/${SCRIPT_NAME%.sh}.vars"

# Validate required files
if [[ ! -f "$GLOBAL_VARS_FILE" ]]; then
    echo "❌ Missing K8s VM vars: $GLOBAL_VARS_FILE" >&2
    exit 1
fi

# Initialize context tracking arrays
declare -A MASTERS WORKERS
ALL_CONTEXTS=()
ALL_VMS=()
parse_vars() {
    local file="$1"
    local current_context=""
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        case "$key" in
            context)
                current_context="$value"
                ALL_CONTEXTS+=("$current_context")
                eval "MASTERS_$current_context=()"
                eval "WORKERS_$current_context=()"
                ;;
            master)
                eval "MASTERS_$current_context+=(\"$value\")"
                ALL_VMS+=("$value")
                ;;
            master-worker)
                eval "MASTERS_$current_context+=(\"$value\")"
                eval "WORKERS_$current_context+=(\"$value\")"
                ALL_VMS+=("$value")
                ;;
            worker)
                eval "WORKERS_$current_context+=(\"$value\")"
                ALL_VMS+=("$value")
                ;;
            *)
                ALL_VMS+=("$key")
                ;;
        esac
    done < "$file"
}

parse_vars "$GLOBAL_VARS_FILE"
[[ -f "$OPTIONAL_VARS_FILE" ]] && parse_vars "$OPTIONAL_VARS_FILE"

# Debug parsed vars
for ctx in "${ALL_CONTEXTS[@]}"; do
    eval "workers=(\"\${WORKERS_$ctx[@]}\")"
    echo "🧪 Parsed workers for context $ctx: ${workers[*]}"
    eval "masters=(\"\${MASTERS_$ctx[@]}\")"
    echo "🧪 Parsed masters for context $ctx: ${masters[*]}"
    echo
done

# DNS check
check_dns() {
    echo "🔍 Checking if DNS is reachable before starting Kubernetes stack..."
    while read -r line; do
        [[ "$line" =~ = ]] || continue
        ip="${line#*=}"
        if timeout 2 bash -c "> /dev/tcp/$ip/53" 2>/dev/null; then
            echo "✅ DNS port 53 reachable on $ip"
            return 0
        fi
    done < "$VARS_DIR/global/US103-AD-DCs.vars"
    echo "❌ No DNS servers reachable on port 53"
    return 1
}

# Try DNS first, otherwise start ADDS
if ! check_dns; then
    echo "🚨 DNS not responding. Attempting to start ADDS/DNS servers..."
    "$SCRIPT_DIR/us103-start-adds.sh"
    echo "⏳ Waiting for DNS to become available..."
    until check_dns; do
        sleep 5
    done
    echo "✅ DNS is now up!"
fi

# Start VMs and uncordon once ready
for ctx in "${ALL_CONTEXTS[@]}"; do
    echo "📦 Starting all K8s VMs for context: $ctx"
    eval "masters=(\"\${MASTERS_$ctx[@]}\")"
    eval "workers=(\"\${WORKERS_$ctx[@]}\")"
    all_nodes=("${masters[@]}" "${workers[@]}")

    for vm in "${all_nodes[@]}"; do
        echo "📦 Starting VMs using xo-cli..."
        "$LIBEXEC_DIR/us103-start-xo-vm.sh" "$vm"
    done

    echo "🔄 Switching to context $ctx..."
    kubectl config use-context "$ctx"

    echo "⏳ Waiting for Kubernetes API server to respond in context '$ctx'..."
    for i in {1..20}; do
        if kubectl cluster-info >/dev/null 2>&1; then
            echo "✅ Kubernetes API server is available for context '$ctx'"
            break
        fi
        echo "🔄 API server not ready yet, retrying..."
        sleep 5
    done

    echo "⏳ Waiting for listed Kubernetes nodes to be Ready in context '$ctx'..."
    for i in {1..20}; do
        all_ready=1
        for node in "${all_nodes[@]}"; do
            status=$(kubectl get node "$node" --no-headers 2>/dev/null | awk '{print $2}')
            if [[ "$status" != "Ready" ]]; then
                echo "⏳ $node not ready yet in $ctx"
                all_ready=0
            fi
        done
        if [[ $all_ready -eq 1 ]]; then
            echo "✅ All listed nodes Ready in $ctx"
            break
        fi
        sleep 5
    done

    # Only uncordon after all nodes are Ready
    for worker in "${workers[@]}"; do
        echo "🔓 Uncordoning worker node: $worker"
        kubectl uncordon "$worker" || echo "⚠️ Could not uncordon $worker"
    done

done

# Handle optional standalone VMs (not in context)
if [[ -f "$OPTIONAL_VARS_FILE" ]]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^(context|master|worker|master-worker)$ ]] && continue
        echo "📦 Starting optional VM: $key"
        "$LIBEXEC_DIR/us103-start-xo-vm.sh" "$key"
    done < "$OPTIONAL_VARS_FILE"
fi

echo "✅ All done."

