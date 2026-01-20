#!/bin/bash

# Security Configuration Script for Ubuntu 24.04 VPS
# Configures Firewall (UFW), Fail2ban, and Auto-updates

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

# SSH Port Configuration
SSH_PORT=${SSH_PORT:-22}

log_step "Installing Security Tools..."
apt-get install -y ufw fail2ban unattended-upgrades

log_step "Configuring UFW Firewall..."
# Reset UFW
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (Custom Port)
log_info "Allowing SSH on port $SSH_PORT"
ufw allow $SSH_PORT/tcp

# Allow HTTP/HTTPS (Web Server)
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp

# Allow Blitz Panel
ufw allow 8000/tcp

# Allow Automation Service
ufw allow 8080/tcp

# Allow WireGuard
ufw allow 51820/udp

# Enable UFW
echo "y" | ufw enable

log_step "Configuring Fail2ban..."
# Create local jail config
cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

systemctl enable fail2ban
systemctl restart fail2ban

log_step "Configuring Unattended Upgrades..."
# Enable automatic updates
echo 'Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}";
        "${distro_id}:${distro_codename}-security";
        "${distro_id}ESMApps:${distro_codename}-apps-security";
        "${distro_id}ESM:${distro_codename}-infra-security";
};' > /etc/apt/apt.conf.d/50unattended-upgrades

echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";' > /etc/apt/apt.conf.d/20auto-upgrades

systemctl enable unattended-upgrades
systemctl restart unattended-upgrades

log_info "Security configuration completed!"
ufw status verbose
