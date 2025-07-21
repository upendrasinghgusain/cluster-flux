#!/bin/bash
set -e                 # Exit immediately if a command exits with a non-zero status.
set -u                 # Treat unset variables as an error when substituting.
set -o pipefail        # Exit if any command in a pipeline fails.

# --- Configuration Variables ---
# General
RESOURCE_GROUP_NAME="rg-clusterflux"
LOCATION="uksouth" # Choose your desired Azure region (e.g., westeurope, eastus)

# Virtual Network (VNet)
VNET_NAME="K3sVNet"
VNET_ADDRESS_PREFIX="10.0.0.0/16"
SUBNET_NAME="K3sSubnet"
SUBNET_ADDRESS_PREFIX="10.0.0.0/24"

# Network Security Group (NSG)
NSG_NAME="K3sNSG"

# Using '*' for source address prefixes as requested for PoC (any access)
# IMPORTANT: For production, restrict this to specific trusted IPs or use Azure Bastion/VPN.
YOUR_PUBLIC_IP="*" # Allowing SSH from any IP (0.0.0.0/0)

# Virtual Machines (VMs)
VM_PREFIX="k3s-server"
ADMIN_USERNAME="upendragusain" # Your desired SSH username
SSH_PUBLIC_KEY_PATH="~/.ssh/id_rsa.pub" # Path to your SSH public key on azure cli

# Public IP addresses for VMs (will be created automatically)
VM1_PUBLIC_IP_NAME="${VM_PREFIX}1-pip"
VM2_PUBLIC_IP_NAME="${VM_PREFIX}2-pip"
VM3_PUBLIC_IP_NAME="${VM_PREFIX}3-pip"

# Private IP addresses for VMs (static assignment)
VM1_PRIVATE_IP="10.0.0.4"
VM2_PRIVATE_IP="10.0.0.5"
VM3_PRIVATE_IP="10.0.0.6"

# Azure Load Balancer (for application ingress)
LB_NAME="K3sAppLB"
LB_PUBLIC_IP_NAME="K3sAppLBPublicIP"
# Initial NodePort for Traefik HTTP. You'll confirm this after K3s installation.
# This is typically 30080 for HTTP and 30443 for HTTPS if Traefik is enabled by default.
TRAEFIK_HTTP_NODEPORT=30080
TRAEFIK_HTTPS_NODEPORT=30443

# K3s Token (for post-provisioning K3s installation)
K3S_TOKEN="YOUR_SECURE_K3S_TOKEN" # <<< IMPORTANT: Replace with your actual K3s token

echo "--- Starting Azure Infrastructure Provisioning ---"

# --- 1. Create Resource Group ---
echo "1. Creating Resource Group: $RESOURCE_GROUP_NAME in $LOCATION..."
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"

# --- 2. Create Virtual Network (VNet) and Subnet ---
echo "2. Creating Virtual Network: $VNET_NAME with Subnet: $SUBNET_NAME..."
az network vnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VNET_NAME" \
    --address-prefix "$VNET_ADDRESS_PREFIX" \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefix "$SUBNET_ADDRESS_PREFIX"

# --- 3. Create Network Security Group (NSG) and Rules ---
echo "3. Creating Network Security Group: $NSG_NAME..."
az network nsg create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$NSG_NAME"

echo "   - Adding NSG rule: Allow SSH from any IP (*)..."
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "$NSG_NAME" \
    --name "AllowSSHFromAnywhere" \
    --priority 100 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --destination-port-ranges 22 \
    --source-address-prefixes "$YOUR_PUBLIC_IP" \
    --destination-address-prefixes "*"

echo "   - Adding NSG rule: Allow K3s internal communication within VNet..."
# Corrected: Port ranges are space-separated, not comma-separated within one string
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "$NSG_NAME" \
    --name "AllowK3sInternal" \
    --priority 200 \
    --direction Inbound \
    --access Allow \
    --protocol "*" \
    --destination-port-ranges "6443" "2379-2380" "8472" "10250" \
    --source-address-prefixes "*" \
    --destination-address-prefixes "*"

echo "   - Adding NSG rule: Allow Azure Load Balancer health probes (to NodePorts)..."
# Corrected: Port ranges are space-separated, not comma-separated within one string
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "$NSG_NAME" \
    --name "AllowLBHealthProbe" \
    --priority 300 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --destination-port-ranges "$TRAEFIK_HTTP_NODEPORT" "$TRAEFIK_HTTPS_NODEPORT" \
    --source-address-prefixes "AzureLoadBalancer" \
    --destination-address-prefixes "*"

echo "   - Associating NSG with Subnet..."
az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --network-security-group "$NSG_NAME"

# --- 4. Create Virtual Machines (VMs) ---
echo "4. Creating 3 K3s Server VMs with Public IPs..."

# VM 1
echo "   - Creating VM 1: ${VM_PREFIX}1 (Private IP: $VM1_PRIVATE_IP, Public IP: will be assigned)..."
az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "${VM_PREFIX}1" \
    --image Ubuntu2204 \
    --size Standard_B2s \
    --admin-username "$ADMIN_USERNAME" \
    --ssh-key-values "$SSH_PUBLIC_KEY_PATH" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --private-ip-address "$VM1_PRIVATE_IP" \
    --public-ip-address "$VM1_PUBLIC_IP_NAME" \
    --nsg "" # NSG is applied at subnet level, so no direct NSG on NIC

# VM 2
echo "   - Creating VM 2: ${VM_PREFIX}2 (Private IP: $VM2_PRIVATE_IP, Public IP: will be assigned)..."
az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "${VM_PREFIX}2" \
    --image Ubuntu2204 \
    --size Standard_B2s \
    --admin-username "$ADMIN_USERNAME" \
    --ssh-key-values "$SSH_PUBLIC_KEY_PATH" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --private-ip-address "$VM2_PRIVATE_IP" \
    --public-ip-address "$VM2_PUBLIC_IP_NAME" \
    --nsg ""

# VM 3
echo "   - Creating VM 3: ${VM_PREFIX}3 (Private IP: $VM3_PRIVATE_IP, Public IP: will be assigned)..."
az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "${VM_PREFIX}3" \
    --image Ubuntu2204 \
    --size Standard_B2s \
    --admin-username "$ADMIN_USERNAME" \
    --ssh-key-values "$SSH_PUBLIC_KEY_PATH" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --private-ip-address "$VM3_PRIVATE_IP" \
    --public-ip-address "$VM3_PUBLIC_IP_NAME" \
    --nsg ""

# --- 5. Create Azure Standard Load Balancer for Application Ingress ---
echo "5. Creating Azure Standard Load Balancer: $LB_NAME..."

# Create Public IP for the Load Balancer Frontend
echo "   - Creating Public IP for Load Balancer: $LB_PUBLIC_IP_NAME..."
az network public-ip create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$LB_PUBLIC_IP_NAME" \
    --sku Standard \
    --allocation-method Static \
    --zone 1 2 3 # Optional: Use zones for zonal redundancy if your region supports it

# Create the Load Balancer
echo "   - Creating the Load Balancer resource..."
az network lb create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$LB_NAME" \
    --sku Standard \
    --public-ip-address "$LB_PUBLIC_IP_NAME" \
    --frontend-ip-name "LBFrontend"

# Create a Backend Pool
echo "   - Creating Backend Pool and adding VM Network Interfaces..."
az network lb address-pool create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --lb-name "$LB_NAME" \
    --name "K3sBackendPool"

# --- Add VMs to Backend Pool ---
# Add VM 1 to Backend Pool
echo "   - Adding ${VM_PREFIX}1 to Load Balancer Backend Pool..."
# Retrieve NIC and primary IP configuration names for VM1
VM1_NIC_ID=$(az vm show -g "$RESOURCE_GROUP_NAME" -n "${VM_PREFIX}1" --query 'networkProfile.networkInterfaces[0].id' -o tsv)
VM1_NIC_NAME=$(basename "$VM1_NIC_ID")
VM1_IP_CONFIG_NAME=$(az network nic ip-config list \
                        --resource-group "$RESOURCE_GROUP_NAME" \
                        --nic-name "$VM1_NIC_NAME" \
                        --query '[?primary==`true`].name' -o tsv)

if [ -z "$VM1_NIC_NAME" ] || [ -z "$VM1_IP_CONFIG_NAME" ]; then
    echo "Error: Failed to retrieve NIC or IP config for ${VM_PREFIX}1. Exiting." >&2
    exit 1
fi

az network nic ip-config update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nic-name "$VM1_NIC_NAME" \
    --name "$VM1_IP_CONFIG_NAME" \
    --lb-name "$LB_NAME" \
    --lb-address-pool "K3sBackendPool"

# Add VM 2 to Backend Pool
echo "   - Adding ${VM_PREFIX}2 to Load Balancer Backend Pool..."
# Retrieve NIC and primary IP configuration names for VM2
VM2_NIC_ID=$(az vm show -g "$RESOURCE_GROUP_NAME" -n "${VM_PREFIX}2" --query 'networkProfile.networkInterfaces[0].id' -o tsv)
VM2_NIC_NAME=$(basename "$VM2_NIC_ID")
VM2_IP_CONFIG_NAME=$(az network nic ip-config list \
                        --resource-group "$RESOURCE_GROUP_NAME" \
                        --nic-name "$VM2_NIC_NAME" \
                        --query '[?primary==`true`].name' -o tsv)

if [ -z "$VM2_NIC_NAME" ] || [ -z "$VM2_IP_CONFIG_NAME" ]; then
    echo "Error: Failed to retrieve NIC or IP config for ${VM_PREFIX}2. Exiting." >&2
    exit 1
fi

az network nic ip-config update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nic-name "$VM2_NIC_NAME" \
    --name "$VM2_IP_CONFIG_NAME" \
    --lb-name "$LB_NAME" \
    --lb-address-pool "K3sBackendPool"

# Add VM 3 to Backend Pool
echo "   - Adding ${VM_PREFIX}3 to Load Balancer Backend Pool..."
# Retrieve NIC and primary IP configuration names for VM3
VM3_NIC_ID=$(az vm show -g "$RESOURCE_GROUP_NAME" -n "${VM_PREFIX}3" --query 'networkProfile.networkInterfaces[0].id' -o tsv)
VM3_NIC_NAME=$(basename "$VM3_NIC_ID")
VM3_IP_CONFIG_NAME=$(az network nic ip-config list \
                        --resource-group "$RESOURCE_GROUP_NAME" \
                        --nic-name "$VM3_NIC_NAME" \
                        --query '[?primary==`true`].name' -o tsv)

if [ -z "$VM3_NIC_NAME" ] || [ -z "$VM3_IP_CONFIG_NAME" ]; then
    echo "Error: Failed to retrieve NIC or IP config for ${VM_PREFIX}3. Exiting." >&2
    exit 1
fi

az network nic ip-config update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nic-name "$VM3_NIC_NAME" \
    --name "$VM3_IP_CONFIG_NAME" \
    --lb-name "$LB_NAME" \
    --lb-address-pool "K3sBackendPool"


# --- Rest of the Load Balancer configuration ---
# Create Health Probe for Traefik's HTTP NodePort
echo "   - Creating Health Probe for Traefik HTTP NodePort ($TRAEFIK_HTTP_NODEPORT)..."
az network lb probe create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --lb-name "$LB_NAME" \
    --name "TraefikHTTPProbe" \
    --protocol Tcp \
    --port "$TRAEFIK_HTTP_NODEPORT" \
    --interval 5 \
    --threshold 2

# Create Load Balancing Rule for HTTP (Port 80)
echo "   - Creating Load Balancing Rule for HTTP (Port 80)..."
az network lb rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --lb-name "$LB_NAME" \
    --name "HTTPRule" \
    --protocol Tcp \
    --frontend-port 80 \
    --backend-port "$TRAEFIK_HTTP_NODEPORT" \
    --frontend-ip-name "LBFrontend" \
    --backend-pool-name "K3sBackendPool" \
    --probe-name "TraefikHTTPProbe" \
    --disable-outbound-snat true # Recommended for Standard LB

# Create Load Balancing Rule for HTTPS (Port 443)
echo "   - Creating Load Balancing Rule for HTTPS (Port 443)..."
az network lb rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --lb-name "$LB_NAME" \
    --name "HTTPSRule" \
    --protocol Tcp \
    --frontend-port 443 \
    --backend-port "$TRAEFIK_HTTPS_NODEPORT" \
    --frontend-ip-name "LBFrontend" \
    --backend-pool-name "K3sBackendPool" \
    --probe-name "TraefikHTTPProbe" \
    --disable-outbound-snat true

echo "--- Azure Infrastructure Provisioning Complete ---"

# --- Output Important Information ---
echo ""
echo "--- Important Information for K3s Installation ---"

echo "VM Public IPs (for SSH access):"
az network public-ip show --resource-group "$RESOURCE_GROUP_NAME" --name "$VM1_PUBLIC_IP_NAME" --query ipAddress -o tsv
az network public-ip show --resource-group "$RESOURCE_GROUP_NAME" --name "$VM2_PUBLIC_IP_NAME" --query ipAddress -o tsv
az network public-ip show --resource-group "$RESOURCE_GROUP_NAME" --name "$VM3_PUBLIC_IP_NAME" --query ipAddress -o tsv

echo "Azure Load Balancer Public IP (for application access):"
az network public-ip show --resource-group "$RESOURCE_GROUP_NAME" --name "$LB_PUBLIC_IP_NAME" --query ipAddress -o tsv

echo ""
echo "--- Next Steps: Install K3s on your VMs ---"
echo "1. SSH into vm1 using its public IP and your SSH key (e.g., ssh -i ~/.ssh/id_rsa.pub ${ADMIN_USERNAME}@<vm1-public-ip>)"
echo "2. Run the K3s installation command on vm1:"
echo "   curl -sfL https://get.k3s.io | K3S_TOKEN=\"${K3S_TOKEN}\" sh -s - server \\"
echo "       --cluster-init \\"
echo "       --node-ip=${VM1_PRIVATE_IP} \\"
echo "       --tls-san=${VM2_PRIVATE_IP} \\"
echo "       --tls-san=${VM3_PRIVATE_IP} \\"
echo "       --tls-san=$(az network public-ip show --resource-group "$RESOURCE_GROUP_NAME" --name "$VM1_PUBLIC_IP_NAME" --query ipAddress -o tsv) \\"
echo "       --tls-san=$(az network public-ip show --resource-group "$RESOURCE_GROUP_NAME" --name "$VM2_PUBLIC_IP_NAME" --query ipAddress -o tsv) \\"
echo "       --tls-san=$(az network public-ip show --resource-group "$RESOURCE_GROUP_NAME" --name "$VM3_PUBLIC_IP_NAME" --query ipAddress -o tsv) \\"
echo "       --tls-san=$(az network public-ip show --resource-group "$RESOURCE_GROUP_NAME" --name "$LB_PUBLIC_IP_NAME" --query ipAddress -o tsv)"
echo ""
echo "3. Wait for vm1 to be fully up (check with 'sudo systemctl status k3s')."
echo "4. SSH into vm2 and vm3 (separately) and run the K3s join command:"
echo "   curl -sfL https://get.k3s.io | K3S_TOKEN=\"${K3S_TOKEN}\" sh -s - server \\"
echo "       --server https://${VM1_PRIVATE_IP}:6443 \\"
echo "       --node-ip=${VM2_PRIVATE_IP} # Use ${VM3_PRIVATE_IP} for vm3"
echo ""
echo "5. After all K3s servers are running, verify the cluster from vm1:"
echo "   sudo k3s kubectl get nodes"
echo ""
echo "sudo chmod 644 /etc/rancher/k3s/k3s.yaml"
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
echo "6. Get Traefik's NodePorts (from vm1):"
echo "   kubectl get svc -n kube-system traefik -o jsonpath='{.spec.ports}'"
echo "   (Look for the nodePort values for ports 80 and 443, and update your Azure Load Balancer rules if needed)"
echo ""
echo "Remember to update your DNS 'A' record for your fake domain to point to the Azure Load Balancer Public IP."


#upendragusain@k3s-server1:~$ kubectl get svc -n kube-system traefik -o jsonpath='{.spec.ports}'
#[{"name":"web","nodePort":30234,"port":80,"protocol":"TCP","targetPort":"web"},{"name":"websecure","nodePort":32151,"port":443,"protocol":"TCP","targetPort":"websecure"}]


# # --- IMPORTANT: Replace with your actual Resource Group Name and LB Name ---
# RESOURCE_GROUP_NAME="K3sClusterRG" # Ensure this matches your script's value
# LB_NAME="K3sAppLB"                   # Ensure this matches your script's value

# NEW_HTTP_NODEPORT=30234
# NEW_HTTPS_NODEPORT=32151

# echo "Updating Azure Load Balancer rules and probes to match K3s NodePorts..."

# # Update Health Probe for HTTP
# echo "  - Updating Health Probe 'TraefikHTTPProbe' to port $NEW_HTTP_NODEPORT..."
# az network lb probe update \
#     --resource-group "$RESOURCE_GROUP_NAME" \
#     --lb-name "$LB_NAME" \
#     --name "TraefikHTTPProbe" \
#     --port "$NEW_HTTP_NODEPORT"

# # Update Load Balancing Rule for HTTP (Port 80)
# echo "  - Updating LB Rule 'HTTPRule' backend port to $NEW_HTTP_NODEPORT..."
# az network lb rule update \
#     --resource-group "$RESOURCE_GROUP_NAME" \
#     --lb-name "$LB_NAME" \
#     --name "HTTPRule" \
#     --backend-port "$NEW_HTTP_NODEPORT"

# # Update Load Balancing Rule for HTTPS (Port 443)
# echo "  - Updating LB Rule 'HTTPSRule' backend port to $NEW_HTTPS_NODEPORT..."
# # Note: The probe for HTTPS is likely still the HTTP one unless you created a separate HTTPS probe
# # For simplicity, we are assuming the probe you named TraefikHTTPProbe is also used for HTTPS rule.
# # If you had created a separate HTTPS probe for port 30443, you would update that too.
# az network lb rule update \
#     --resource-group "$RESOURCE_GROUP_NAME" \
#     --lb-name "$LB_NAME" \
#     --name "HTTPSRule" \
#     --backend-port "$NEW_HTTPS_NODEPORT"

# echo "Azure Load Balancer rules and probes updated successfully!"
# echo "You can now try accessing your applications via the Load Balancer's public IP."


#kubectl edit svc -n kube-system traefik
# #
# ports:
#   - name: web
#     nodePort: 30234
#     port: 80
#     protocol: TCP
#     targetPort: 8000 # <-- Changed to 8000
#   - name: websecure
#     nodePort: 32151
#     port: 443
#     protocol: TCP
#     targetPort: 8443 # <-- Changed to 8443
# #
#kubectl get svc -n kube-system traefik -o yaml

# update host file with load balancer public ip

#http://clusterflux.co.uk/swagger/index.html

#sudo cat /etc/rancher/k3s/k3s.yaml
#copy and it to .kube config folder and update the ip with vm1's public ip

#kubectl apply -f C:\Development\PoCs\ClusterFlux\k8s-manifests\ha-ingress-web-api.yaml

#kubectl scale deployment aspnet-api-deployment --replicas=10
#kubectl get pods -l app=aspnet-api -o wide