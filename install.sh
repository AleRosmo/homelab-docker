#!/bin/bash

# Update and upgrade system
sudo apt update && sudo apt upgrade -y

# Install dependencies for Docker
echo "Installing dependencies for Docker..."
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

# Set static IP configuration
INTERFACE="eth0"
IP_ADDRESS="192.168.188.201"
GATEWAY="192.168.188.1"
DNS="8.8.8.8 8.8.4.4"

echo "Configuring static IP for $INTERFACE..."
sudo tee /etc/network/interfaces.d/$INTERFACE.cfg > /dev/null <<EOL
auto $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDRESS
    netmask 255.255.255.0
    gateway $GATEWAY
    dns-nameservers $DNS
EOL

# Restart networking service to apply changes
sudo systemctl restart networking

# Verify network configuration
ifconfig $INTERFACE

# Verify Docker installation
docker --version
docker compose version

# Add current user to the Docker group (optional, requires re-login)
sudo usermod -aG docker $USER

# Disable PC speaker
echo "Disabling PC speaker..."
echo "blacklist pcspkr" | sudo tee /etc/modprobe.d/nobeep.conf > /dev/null
sudo rmmod pcspkr

# Final message
echo "Setup complete: Docker is installed, static IP is configured, and PC speaker is disabled."