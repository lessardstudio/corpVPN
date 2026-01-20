#!/bin/bash

# Master Deployment Script for Corporate VPN Gateway on Ubuntu 24.04 VPS
# This script orchestrates the entire deployment process

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script as root"
    exit 1
fi

# 1. System Preparation
log_step "1. Starting System Preparation..."
chmod +x scripts/prepare_vps.sh
./scripts/prepare_vps.sh

# 2. Security Configuration
log_step "2. Configuring Security..."
chmod +x scripts/configure_security.sh
./scripts/configure_security.sh

# 3. WireGuard Setup (Host Mode)
log_step "3. Setting up WireGuard..."
chmod +x scripts/setup-wireguard.sh
# Check if WireGuard is already configured
if [ ! -f "/etc/wireguard/wg0.conf" ]; then
    ./scripts/setup-wireguard.sh
else
    log_info "WireGuard already configured, skipping setup."
fi

# 4. Project Setup
log_step "4. Setting up Hysteria2 Project..."
chmod +x setup_hysteria2.sh
./setup_hysteria2.sh

# 5. Start Services
log_step "5. Starting Docker Services..."
docker-compose up -d

log_step "6. Verifying Deployment..."
sleep 10
docker-compose ps
wg show

log_info "Deployment Completed Successfully!"
echo ""
echo "Access Information:"
echo "- Blitz Panel: https://YOUR_DOMAIN:8000"
echo "- Hysteria2: YOUR_DOMAIN:443"
echo ""
echo "Next Steps:"
echo "1. Edit .env file with your real secrets"
echo "2. Run './scripts/setup-ssl.sh production' to get Let's Encrypt certificates"
echo "3. Restart services: 'docker-compose restart'"
