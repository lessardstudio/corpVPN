#!/bin/bash

# Setup User and SSH Hardening Script
# Creates a sudo user and secures SSH configuration

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

log_warn() {
    echo -e "${RED}[WARN]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Configuration variables (defaults if not set)
VPS_USER=${VPS_USER:-"admin_user"}
VPS_PASSWORD=${VPS_PASSWORD:-"ChangeMe123!"}
SSH_PORT=${SSH_PORT:-22}

log_step "1. Creating new user: $VPS_USER"

# Check if user exists
if id "$VPS_USER" &>/dev/null; then
    log_warn "User $VPS_USER already exists. Skipping creation."
else
    # Create user with home directory and bash shell
    useradd -m -s /bin/bash -G sudo "$VPS_USER"
    
    # Set password
    echo "$VPS_USER:$VPS_PASSWORD" | chpasswd
    
    log_info "User $VPS_USER created and added to sudo group."
fi

# Ensure .ssh directory exists for the new user (optional, for key auth later)
mkdir -p /home/$VPS_USER/.ssh
chmod 700 /home/$VPS_USER/.ssh
chown $VPS_USER:$VPS_USER /home/$VPS_USER/.ssh

log_step "2. Configuring SSH Security"

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_CONFIG="/etc/ssh/sshd_config.bak.$(date +%F_%T)"

# Backup config
cp $SSHD_CONFIG $BACKUP_CONFIG
log_info "Backed up SSH config to $BACKUP_CONFIG"

# Configure Port
if grep -q "^Port " $SSHD_CONFIG; then
    sed -i "s/^Port .*/Port $SSH_PORT/" $SSHD_CONFIG
else
    echo "Port $SSH_PORT" >> $SSHD_CONFIG
fi

# Disable Root Login
if grep -q "^PermitRootLogin " $SSHD_CONFIG; then
    sed -i "s/^PermitRootLogin .*/PermitRootLogin no/" $SSHD_CONFIG
else
    echo "PermitRootLogin no" >> $SSHD_CONFIG
fi

# Disable Empty Passwords
if grep -q "^PermitEmptyPasswords " $SSHD_CONFIG; then
    sed -i "s/^PermitEmptyPasswords .*/PermitEmptyPasswords no/" $SSHD_CONFIG
else
    echo "PermitEmptyPasswords no" >> $SSHD_CONFIG
fi

# Optional: Disable Password Auth if keys are used (not enabling by default to avoid lockout)
# echo "PasswordAuthentication no" >> $SSHD_CONFIG

log_step "3. Restarting SSH Service"
# Test config first
if sshd -t; then
    systemctl restart ssh
    log_info "SSH service restarted. New Port: $SSH_PORT"
    log_warn "IMPORTANT: Do not close this session until you verified you can login with the new user!"
    log_warn "Command: ssh -p $SSH_PORT $VPS_USER@<your-ip>"
else
    log_warn "SSH configuration test failed! Restoring backup..."
    cp $BACKUP_CONFIG $SSHD_CONFIG
    systemctl restart ssh
    exit 1
fi

log_info "User setup and SSH hardening completed!"
