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

# # Provide instructions for exposing containers
# echo "To expose a container to the network, use the '--network host' option when running a container."


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

# Curl Network Setup script from GitHub and run it
NETSETUP_FILE="/tmp/debian-netsetup.sh"
echo "Downloading Network Setup script..."
curl -fsSL https://raw.githubusercontent.com/AleRosmo/scripts/refs/heads/main/debian-netsetup.sh -o $NETSETUP_FILE
chmod +x $NETSETUP_FILE
bash -c $NETSETUP_FILE

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