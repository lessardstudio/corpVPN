#!/bin/bash

# System Preparation Script for Ubuntu 24.04 VPS
# This script installs necessary dependencies, Docker, and WireGuard

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

log_step "Updating system packages..."
apt-get update
apt-get upgrade -y
apt-get install -y curl wget git openssl nano htop ufw apt-transport-https ca-certificates gnupg lsb-release

log_step "Installing WireGuard tools..."
apt-get install -y wireguard wireguard-tools iproute2

log_step "Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/99-sysctl.conf
sysctl -p /etc/sysctl.d/99-sysctl.conf

log_step "Installing Docker..."
# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

log_step "Verifying installations..."
docker --version
wg --version

log_info "System preparation completed successfully!"
