#!/bin/bash

# Marzban setup script for Corporate VPN Gateway
# This script initializes Marzban with required configurations

set -e

echo "Setting up Marzban for Corporate VPN Gateway..."

# Create necessary directories
mkdir -p /var/lib/marzban/{logs,ssl,users}
mkdir -p /var/log/xray

# Generate Reality keys
echo "Generating Reality keys..."
REALITY_KEYS=$(docker run --rm gozargah/marzban xray x25519)
PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "Private key:" | awk '{print $3}')
PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "Public key:" | awk '{print $3}')

# Update xray_config.json with generated keys
sed -i "s/YOUR_PRIVATE_KEY_HERE/$PRIVATE_KEY/g" /var/lib/marzban/xray_config.json
sed -i "s/YOUR_PUBLIC_KEY_HERE/$PUBLIC_KEY/g" /var/lib/marzban/xray_config.json

# Generate WireGuard keys if not provided
if [ -z "$WIREGUARD_PRIVATE_KEY" ]; then
    echo "Generating WireGuard keys..."
    WIREGUARD_PRIVATE_KEY=$(wg genkey)
    WIREGUARD_PUBLIC_KEY=$(echo "$WIREGUARD_PRIVATE_KEY" | wg pubkey)
fi

# Update config with WireGuard keys
sed -i "s/YOUR_WIREGUARD_PRIVATE_KEY/$WIREGUARD_PRIVATE_KEY/g" /var/lib/marzban/xray_config.json
sed -i "s/YOUR_OFFICE_WIREGUARD_PUBLIC_KEY/$WIREGUARD_PUBLIC_KEY/g" /var/lib/marzban/xray_config.json

# Set proper permissions
chmod 600 /var/lib/marzban/xray_config.json
chmod 600 /var/lib/marzban/config.py

echo "Marzban setup completed!"
echo "Reality Private Key: $PRIVATE_KEY"
echo "Reality Public Key: $PUBLIC_KEY"
echo "WireGuard Private Key: $WIREGUARD_PRIVATE_KEY"
echo "WireGuard Public Key: $WIREGUARD_PUBLIC_KEY"
echo ""
echo "IMPORTANT: Update the following in your environment:"
echo "- WireGuard endpoint (YOUR_OFFICE_WIREGUARD_ENDPOINT)"
echo "- Office network settings"
echo "- SSL certificates for domain"