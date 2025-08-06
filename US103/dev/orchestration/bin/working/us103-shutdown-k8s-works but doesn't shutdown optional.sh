#!/bin/bash
# us103-shutdown-k8s.sh
# Cordons all running nodes in the selected cluster context
# Then shuts down the corresponding VMs via centralized shutdown script

SCRIPT_NAME=$(basename "$0")
WORKDIR="/srv/tmp/${SCRIPT_NAME%.*}"
mkdir -p "$WORKDIR"
LOG="$WORKDIR/k8s_shutdown.log"

echo "🔧 Shutting down Kubernetes cluster..." | tee -a "$LOG"

K8S_VAR_FILE="$(dirname "$0")/../vars/global/US103-k8s-servers.vars"
if [[ ! -f "$K8S_VAR_FILE" ]]; then
  echo "❌ K8s vars file not found: $K8S_VAR_FILE"
  exit 1
fi
source "$K8S_VAR_FILE"

echo "[INFO] Switching kubectl context to: $K8S_CONTEXT" | tee -a "$LOG"
kubectl config use-context "$K8S_CONTEXT" &>> "$LOG"

SHUTDOWN_LIST=()

# Get all Ready nodes
RUNNING_NODES=$(kubectl get nodes --no-headers | awk '/ Ready / { print $1 }')

for node in $RUNNING_NODES; do
  echo "[INFO] Cordoning node: $node" | tee -a "$LOG"
  kubectl cordon "$node" &>> "$LOG"
  SHUTDOWN_LIST+=("$node")
done

# Optional shutdown VMs
OPTIONAL_VARS_FILE="$(dirname "$0")/../vars/optional/us103-start-k8s.vars"
if [[ -f "$OPTIONAL_VARS_FILE" ]]; then
  echo "[INFO] Loading optional shutdown targets from $OPTIONAL_VARS_FILE" | tee -a "$LOG"
  source "$OPTIONAL_VARS_FILE"
  SHUTDOWN_LIST+=("${OPTIONAL_NODES[@]}")
fi

# Call centralized shutdown script
SHUTDOWN_SCRIPT="$(dirname "$0")/../libexec/us103-shutdown-xo-vm.sh"
echo "🔧 Delegating VM shutdown to: $SHUTDOWN_SCRIPT" | tee -a "$LOG"
"$SHUTDOWN_SCRIPT" "${SHUTDOWN_LIST[@]}" | tee -a "$LOG"

echo "✅ K8s shutdown done." | tee -a "$LOG"
