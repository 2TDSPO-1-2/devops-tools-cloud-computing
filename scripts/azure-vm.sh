#!/usr/bin/env bash
set -euo pipefail


# used variables for organization sake;

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arkive}" # Resource Group name as -rg-arkive;
LOCATION="${LOCATION:-brazilsouth}" # hardcoded -brazilsouth as region
VM_NAME="${VM_NAME:-vm-arkive}"
ADMIN_USER="${ADMIN_USER:-arkiveadm}"
VM_SIZE="${VM_SIZE:-Standard_B2ms}"
IMAGE="${IMAGE:-Ubuntu2204}"
API_PORT="${API_PORT:-8080}"

# checking for azure credentials
echo "Checking Azure login..."
az account show --output table >/dev/null

# creating resource group
echo "Creating resource group: $RESOURCE_GROUP"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output table

# creating the actual vm 
echo "Creating Linux VM: $VM_NAME"
az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --image "$IMAGE" \
  --size "$VM_SIZE" \
  --admin-username "$ADMIN_USER" \
  --authentication-type ssh \
  --generate-ssh-keys \
  --public-ip-sku Standard \
  --output table

# opening the port
echo "Opening API port: $API_PORT"
az vm open-port \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --port "$API_PORT" \
  --priority 1001 \
  --output table

echo "Installing Docker, Docker Compose plugin, Git and nano inside the VM..."

INSTALL_SCRIPT=$(cat <<EOF
set -e

echo "Updating apt packages..."
sudo apt-get update -y

echo "Installing required base packages..."
sudo apt-get install -y ca-certificates curl gnupg git nano lsb-release

echo "Configuring Docker repository..."
sudo install -m 0755 -d /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

sudo chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release

echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \${VERSION_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Installing Docker Engine and Compose plugin..."
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Enabling Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

echo "Adding $ADMIN_USER to docker group..."
sudo usermod -aG docker $ADMIN_USER

echo "Installed versions:"
docker --version
docker compose version
git --version
nano --version | head -n 1

echo "VM setup completed."
EOF
)

az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --command-id RunShellScript \
  --scripts "$INSTALL_SCRIPT" \
  --output table

PUBLIC_IP=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --show-details \
  --query publicIps \
  --output tsv)

echo ""
echo "======================================="
echo "Azure VM created successfully."
echo "Resource Group: $RESOURCE_GROUP"
echo "VM Name:        $VM_NAME"
echo "Public IP:      $PUBLIC_IP"
echo "SSH command:    ssh $ADMIN_USER@$PUBLIC_IP"
echo "API URL:        http://$PUBLIC_IP:$API_PORT/api/health"
echo "Swagger URL:    http://$PUBLIC_IP:$API_PORT/swagger-ui/index.html"
echo "======================================="
echo ""
echo "Important: after finishing the demo, delete the resource group:"
echo "az group delete --name $RESOURCE_GROUP --yes"