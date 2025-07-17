#!/usr/bin/env bash
set -e

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "🚀 Running Terraform..."
terraform init
terraform apply -auto-approve

echo "📦 Exporting IPs from Terraform output..."

# Create output directory if it doesn't exist
mkdir -p outputs

# Export master and worker IPs
terraform output -raw master_ip > outputs/master_ip.txt
terraform output -json worker_ips | grep -oE '"[^"]+"' | tr -d '"' > outputs/worker_ips.txt


echo "✅ IPs exported to outputs/master_ip.txt and outputs/worker_ips.txt"

echo "🔧 Running setup script..."
chmod +x scripts/setup-k3s-cluster.sh
scripts/setup-k3s-cluster.sh


echo "✅ All done!"
