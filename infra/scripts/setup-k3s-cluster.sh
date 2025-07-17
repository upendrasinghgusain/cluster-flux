#!/bin/bash

set -e

# ✅ Step 1: Read VM IPs from Terraform output files
MASTER_IP=$(cat ./outputs/master_ip.txt)
WORKER_IPS=($(cat ./outputs/worker_ips.txt))

# ✅ Step 2: SSH Config
SSH_USER="upendragusain"
SSH_KEY_PATH="~/.ssh/id_rsa"  # Update to match what you use in Terraform

# ✅ Step 3: Install K3s on master node
echo "Installing K3s server on master node: $MASTER_IP..."
ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP <<EOF
  curl -sfL https://get.k3s.io | sh -
EOF

# ✅ Step 4: Retrieve K3s token from master
echo "Retrieving K3s token from master node..."
K3S_TOKEN=$(ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "sudo cat /var/lib/rancher/k3s/server/node-token")

# ✅ Step 5: Install K3s agents on worker nodes
for ip in "${WORKER_IPS[@]}"; do
  echo "Installing K3s agent on worker node: $ip..."
  ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no $SSH_USER@$ip <<EOF
    curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$K3S_TOKEN sh -
EOF
done

echo "✅ K3s cluster is up with 1 master and ${#WORKER_IPS[@]} workers."
