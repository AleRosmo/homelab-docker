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
    net-tools

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update apt and install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Verify Docker installation
docker --version
docker compose version

# Add current user to the Docker group (optional, requires re-login)
sudo usermod -aG docker $USER
echo "You need to log out and back in to use Docker as a non-root user."

# Prompt for network configuration
echo "Please enter the following network configuration details:"
read -p "Interface name (e.g., eth0): " INTERFACE
read -p "IP Address (e.g., 192.168.1.100): " IP_ADDRESS
read -p "Subnet Mask (e.g., 255.255.255.0): " SUBNET_MASK
read -p "Gateway (e.g., 192.168.1.1): " GATEWAY
read -p "DNS Server (e.g., 8.8.8.8): " DNS

# Validate IP inputs (basic regex check)
if ! [[ $IP_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
   ! [[ $SUBNET_MASK =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
   ! [[ $GATEWAY =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
   ! [[ $DNS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid IP address format. Please check your inputs."
    exit 1
fi

echo "Configuring static IP for $INTERFACE..."

# Configure network
NETWORK_CONFIG="/etc/network/interfaces.d/$INTERFACE.cfg"
sudo tee $NETWORK_CONFIG > /dev/null <<EOL
auto $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDRESS
    netmask $SUBNET_MASK
    gateway $GATEWAY
    dns-nameservers $DNS
EOL

# Restart networking service
echo "Restarting network service to apply the static IP configuration..."
sudo systemctl restart networking

# Verify network configuration
ifconfig $INTERFACE

# Disable PC speaker
echo "Disabling PC speaker..."
echo "blacklist pcspkr" | sudo tee /etc/modprobe.d/nobeep.conf > /dev/null
sudo rmmod pcspkr || true # Ignore error if the module is not loaded

# Prompt for final reboot
read -p "Configuration complete. Do you want to reboot now? (y/n): " REBOOT
if [[ $REBOOT == "y" || $REBOOT == "Y" ]]; then
    sudo reboot
else
    echo "Reboot skipped. Please reboot later to apply all changes."
fi