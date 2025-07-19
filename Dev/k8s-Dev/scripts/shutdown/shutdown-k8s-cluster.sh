#!/bin/bash
#  Prerequisites:  this assumes you have run the following on the jump station:
#----------------------------------------------
#  ssh-keygen -t ed25519 -C "k8s-automation"
#       # accept defaults on all prompts
#  
# ssh-copy-id your-username@<node-ip>
#     #  use the username to login to the node
#     #  do this for each node/master
#  
#----------------------------------------------
#  on each node/master:  
#  sudo visudo
#      #  add to bottom of file: bssadm ALL=(ALL) NOPASSWD: /sbin/shutdown

# === Configuration ===
SSH_USER="bssadm"  # Change this to your actual username on the nodes
BASE_DIR="/bss-scripts/k8s/shutdown-k8s-cluster"
WORK_DIR="$BASE_DIR/workingdir"
LOG_DIR="$BASE_DIR/logs"
CORDON_LIST="$WORK_DIR/worker-nodes.txt"
MASTER_FILE="$WORK_DIR/master-node.txt"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/shutdown-log-$TIMESTAMP.log"
WORKER_SHUTDOWN_CMD="sudo /sbin/shutdown now"

# === Ensure Directories Exist ===
for dir in "$BASE_DIR" "$WORK_DIR" "$LOG_DIR"; do
  if [ ! -d "$dir" ]; then
    echo "📁 Creating directory $dir..."
    sudo mkdir -p "$dir" || { echo "❌ Failed to create $dir"; exit 1; }
    sudo chown "$USER:$USER" "$dir"
  fi
done

# === Setup Logging ===
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🔧 Kubernetes cluster shutdown started at $TIMESTAMP"
echo "🔍 Detecting all nodes and their IP addresses..."

# === Get Master and Worker Node IPs ===
kubectl get nodes -l node-role.kubernetes.io/control-plane -o wide --no-headers | awk '{print $1,$6}' > "$MASTER_FILE"
kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o wide --no-headers | awk '{print $1,$6}' > "$CORDON_LIST"

echo "📄 Master node:"
cat "$MASTER_FILE"
echo "📄 Worker nodes:"
cat "$CORDON_LIST"

# === Cordon Workers ===
echo "🔒 Cordoning all worker nodes..."
while IFS=' ' read -r node_name node_ip; do
  echo "  - Cordoning $node_name ($node_ip)"
  kubectl cordon "$node_name" || echo "⚠️ Failed to cordon $node_name"
done < "$CORDON_LIST"

sleep 3

# === Shutdown Master ===
read -r MASTER_NAME MASTER_IP < "$MASTER_FILE"
echo "📦 Shutting down master node: $MASTER_NAME ($MASTER_IP)"
ssh "$SSH_USER@$MASTER_IP" "$WORKER_SHUTDOWN_CMD" || echo "⚠️ Failed to shut down master $MASTER_NAME"

# === Shutdown Workers ===
echo "🛑 Shutting down worker nodes..."
while IFS=' ' read -r node_name node_ip; do
  echo "  - Shutting down $node_name ($node_ip)"
  ssh "$SSH_USER@$node_ip" "$WORKER_SHUTDOWN_CMD" || echo "⚠️ Failed to shut down worker $node_name"
done < "$CORDON_LIST"

echo "✅ Cluster shutdown process completed."
echo "📝 Log file saved to $LOG_FILE"
