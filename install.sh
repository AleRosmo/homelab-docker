#!/bin/bash

# Exit on error
set -e

# Update and upgrade system
sudo apt update && sudo apt upgrade -y

# Install dependencies for Docker
echo "Installing Docker and dependencies..."
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    sudo

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# TODO: Do we really need to add Docker's repository? Can't we just install from Debian repo?
# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update apt and install Docker
sudo apt update
# TODO: Is this stuff below really needed? Especially if installing 'docker' package?
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Configure Docker to accept connections from LAN
echo "Configuring Docker to accept LAN connections..."
sudo mkdir -p /etc/docker
sudo mv /etc/docker/daemon.json /etc/docker/daemon.json.bak 2>/dev/null || true
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"]
}
EOF

# Provide instructions for exposing containers
echo "To expose a container to the network, use the '--network host' option when running a container."


# Update Docker service configuration for LAN access
echo "Updating Docker service configuration to remove conflicting flags..."
sudo sed -i 's|ExecStart=.*|ExecStart=/usr/bin/dockerd|' /lib/systemd/system/docker.service

# TODO: Might not be needed as it's already stopped, check.

# Reload systemd configuration and restart Docker
echo "Reloading systemd configuration and restarting Docker..."
sudo systemctl daemon-reload
sudo systemctl restart docker

# Verify Docker is configured and running
echo "Verifying Docker configuration..."
if systemctl is-active --quiet docker; then
    echo "Docker is running and listening on the specified ports."
else
    echo "Docker failed to start. Check logs with 'journalctl -xeu docker.service'."
    exit 1
fi

# Verify Docker is listening on port 2375
echo "Checking if Docker is listening on port 2375..."
if sudo netstat -tuln | grep -q ":2375"; then
    echo "Docker is listening on port 2375."
else
    echo "Docker is not listening on port 2375. Check the daemon.json configuration and Docker logs."
    exit 1
fi

# Add current user to the Docker group (optional, requires re-login)
sudo usermod -aG docker "$USER"
echo "You need to log out and back in to use Docker as a non-root user."

# Function to convert CIDR to subnet mask
cidr_to_netmask() {
    local cidr=$1
    local mask=""
    local i
    for ((i=0; i<4; i++)); do
        if [ "$cidr" -ge 8 ]; then
            mask+=255
            cidr=$((cidr-8))
        else
            mask+=$((256-(2**(8-cidr))))
            cidr=0
        fi
        [ $i -lt 3 ] && mask+=.
    done
    echo "$mask"
}

# Get current network configuration
CURRENT_INTERFACE=$(ip route | grep default | awk '{print $5}')
CURRENT_IP_ADDRESS=$(ip -o -4 addr list "$CURRENT_INTERFACE" | awk '{print $4}' | cut -d/ -f1)
CURRENT_CIDR=$(ip -o -4 addr list "$CURRENT_INTERFACE" | awk '{print $4}' | cut -d/ -f2)
CURRENT_SUBNET_MASK=$(cidr_to_netmask "$CURRENT_CIDR")
CURRENT_GATEWAY=$(ip route | grep default | awk '{print $3}')
CURRENT_DNS="8.8.8.8 8.8.4.4"

# Prompt for network configuration with default values
echo "Please enter the following network configuration details (press Enter to accept default values):"
read -p "Interface name [$CURRENT_INTERFACE]: " INTERFACE
INTERFACE=${INTERFACE:-$CURRENT_INTERFACE}

read -p "IP Address [$CURRENT_IP_ADDRESS]: " IP_ADDRESS
IP_ADDRESS=${IP_ADDRESS:-$CURRENT_IP_ADDRESS}

read -p "Subnet Mask [$CURRENT_SUBNET_MASK]: " SUBNET_MASK
SUBNET_MASK=${SUBNET_MASK:-$CURRENT_SUBNET_MASK}

read -p "Gateway [$CURRENT_GATEWAY]: " GATEWAY
GATEWAY=${GATEWAY:-$CURRENT_GATEWAY}

read -p "DNS Server(s) (space-separated) [$CURRENT_DNS]: " DNS
DNS=${DNS:-$CURRENT_DNS}

# Debug info
echo "Debug: INTERFACE=$INTERFACE"
echo "Debug: IP_ADDRESS=$IP_ADDRESS"
echo "Debug: SUBNET_MASK=$SUBNET_MASK"
echo "Debug: GATEWAY=$GATEWAY"
echo "Debug: DNS=$DNS"

# Validate inputs
# The key change: DNS now checks for one or more space-separated IP addresses
if ! [[ $INTERFACE =~ ^[a-zA-Z0-9]+$ ]] || \
   ! [[ $IP_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
   ! [[ $SUBNET_MASK =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
   ! [[ $GATEWAY =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
   ! [[ $DNS =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)([[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)*$ ]]; then
    echo "Invalid IP address format. Please check your inputs."
    exit 1
fi

echo "Backing up and cleaning /etc/network/interfaces..."
sudo cp /etc/network/interfaces /etc/network/interfaces.bak

sudo bash -c 'cat > /etc/network/interfaces' <<EOL
source /etc/network/interfaces.d/*
EOL

echo "Configuring static IP for $INTERFACE..."
NETWORK_CONFIG="/etc/network/interfaces.d/$INTERFACE.cfg"
sudo tee "$NETWORK_CONFIG" > /dev/null <<EOL
auto $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDRESS
    netmask $SUBNET_MASK
    gateway $GATEWAY
    dns-nameservers $DNS
EOL

echo "Restarting network service to apply the static IP configuration..."
sudo systemctl restart networking

echo "Verifying new interface settings..."
ip addr show "$INTERFACE"

# Disable PC speaker
echo "Disabling PC speaker..."
echo "blacklist pcspkr" | sudo tee /etc/modprobe.d/nobeep.conf > /dev/null
sudo rmmod pcspkr || true # Ignore error if the module is not loaded

# Prompt for final reboot
read -p "Configuration complete. Do you want to reboot now? (y/n): " REBOOT
if [[ "$REBOOT" == "y" || "$REBOOT" == "Y" ]]; then
    sudo reboot
else
    echo "Reboot skipped. Please reboot later to apply all changes."
fi