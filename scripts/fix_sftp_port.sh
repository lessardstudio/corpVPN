#!/bin/bash

# Script to revert SSH/SFTP port to 22 and unblock it in firewall

GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO] $1${NC}"; }

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

log_info "1. Updating SSH configuration to use Port 22..."
sed -i "s/^Port .*/Port 22/" /etc/ssh/sshd_config
if ! grep -q "^Port 22" /etc/ssh/sshd_config; then
    echo "Port 22" >> /etc/ssh/sshd_config
fi

log_info "2. Updating Firewall rules..."
if command -v ufw >/dev/null; then
    ufw allow 22/tcp
    ufw reload
    log_info "UFW updated."
elif command -v firewall-cmd >/dev/null; then
    firewall-cmd --permanent --add-port=22/tcp
    firewall-cmd --reload
    log_info "Firewalld updated."
fi

log_info "3. Restarting SSH service..."
if sshd -t; then
    systemctl restart ssh
    log_info "SSH service restarted on Port 22."
    log_info "You can now connect via SSH/SFTP on port 22."
else
    echo "SSH config check failed! Please check /etc/ssh/sshd_config manually."
    exit 1
fi
