#!/bin/bash

# WireGuard setup script for Corporate VPN Gateway
# This script configures WireGuard tunnel to office network

set -e

echo "Setting up WireGuard tunnel..."

# Configuration variables (should be set via environment variables)
OFFICE_NETWORK="${OFFICE_NETWORK:-192.168.0.0/16}"
OFFICE_WIREGUARD_ENDPOINT="${OFFICE_WIREGUARD_ENDPOINT:-office.example.com:51820}"
OFFICE_WIREGUARD_PUBLIC_KEY="${OFFICE_WIREGUARD_PUBLIC_KEY:-your_office_public_key}"
INTERFACE_NAME="wg0"

# Generate WireGuard keys for VPS side
if [ ! -f "/etc/wireguard/private.key" ]; then
    echo "Generating WireGuard keys..."
    mkdir -p /etc/wireguard
    # Set umask to ensure private key is only readable by root
    old_umask=$(umask)
    umask 077
    wg genkey > /etc/wireguard/private.key
    wg pubkey < /etc/wireguard/private.key > /etc/wireguard/public.key
    umask $old_umask
fi

VPS_PRIVATE_KEY=$(cat /etc/wireguard/private.key)
VPS_PUBLIC_KEY=$(cat /etc/wireguard/public.key)

echo "VPS WireGuard Public Key: $VPS_PUBLIC_KEY"

# Create WireGuard configuration
cat > /etc/wireguard/${INTERFACE_NAME}.conf <<EOF
[Interface]
PrivateKey = ${VPS_PRIVATE_KEY}
Address = 10.0.0.2/32
ListenPort = 51820
DNS = 8.8.8.8, 1.1.1.1

[Peer]
PublicKey = ${OFFICE_WIREGUARD_PUBLIC_KEY}
Endpoint = ${OFFICE_WIREGUARD_ENDPOINT}
AllowedIPs = ${OFFICE_NETWORK}
PersistentKeepalive = 30
EOF

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Setup iptables rules for NAT
cat > /etc/wireguard/setup-iptables.sh <<EOF
#!/bin/bash
# WireGuard iptables rules

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Setup NAT for WireGuard interface
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE
iptables -A FORWARD -i ${INTERFACE_NAME} -j ACCEPT
iptables -A FORWARD -o ${INTERFACE_NAME} -j ACCEPT

# Save iptables rules
iptables-save > /etc/iptables/rules.v4
EOF

chmod +x /etc/wireguard/setup-iptables.sh

# Create systemd service for WireGuard
cat > /etc/systemd/system/wireguard-setup.service <<EOF
[Unit]
Description=WireGuard Setup for Corporate VPN
After=network.target

[Service]
Type=oneshot
ExecStart=/etc/wireguard/setup-iptables.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
systemctl enable wg-quick@${INTERFACE_NAME}.service
systemctl enable wireguard-setup.service

echo "WireGuard setup completed!"
echo "Please provide the following information to your office network administrator:"
echo "VPS Public Key: $VPS_PUBLIC_KEY"
echo "VPS Endpoint: $(curl -s ifconfig.me):51820"
echo "Allowed IPs: 10.0.0.2/32"

# Update Xray config with WireGuard keys
if [ -f "/var/lib/marzban/xray_config.json" ]; then
    sed -i "s/YOUR_WIREGUARD_PRIVATE_KEY/$VPS_PRIVATE_KEY/g" /var/lib/marzban/xray_config.json
    echo "Updated Xray configuration with WireGuard keys"
fi