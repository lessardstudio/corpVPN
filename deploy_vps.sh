#!/bin/bash

# ==============================================================================
# Master Deployment Script for Corporate VPN Gateway
# Supports: Ubuntu, Debian, CentOS, AlmaLinux, Rocky Linux
# Functionality: System Prep, Security, User Setup, Docker, Project Deployment
# ==============================================================================

# ------------------------------------------------------------------------------
# Global Configuration & Logging
# ------------------------------------------------------------------------------
LOG_FILE="deploy_vps.log"
exec > >(tee -a "$LOG_FILE") 2>&1

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1${NC}"; }
log_step() { echo -e "${BLUE}[STEP] $(date '+%Y-%m-%d %H:%M:%S') - $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1${NC}"; }

# Error Handling
trap 'log_error "An error occurred on line $LINENO. Exiting..."; exit 1' ERR

# ------------------------------------------------------------------------------
# 1. OS Detection
# ------------------------------------------------------------------------------
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    log_info "Detected OS: $OS $VER"
    
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            PKG_MANAGER="apt-get"
            PKG_UPDATE="apt-get update && apt-get upgrade -y"
            PKG_INSTALL="apt-get install -y"
            FIREWALL="ufw"
            GROUP_ADD="groupadd"
            ;;
        *"CentOS"*|*"AlmaLinux"*|*"Rocky"*)
            PKG_MANAGER="dnf"
            PKG_UPDATE="dnf update -y"
            PKG_INSTALL="dnf install -y"
            FIREWALL="firewalld"
            GROUP_ADD="groupadd"
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 2. System Preparation
# ------------------------------------------------------------------------------
prepare_system() {
    log_step "Updating system and installing base dependencies..."
    eval $PKG_UPDATE
    
    # Common packages
    PACKAGES="curl wget git nano htop"
    
    # OS Specific packages
    if [[ "$PKG_MANAGER" == "apt-get" ]]; then
        PACKAGES="$PACKAGES ufw fail2ban unattended-upgrades wireguard wireguard-tools iproute2 lsb-release ca-certificates gnupg"
    elif [[ "$PKG_MANAGER" == "dnf" ]]; then
        PACKAGES="$PACKAGES firewalld fail2ban epel-release wireguard-tools iproute"
        # EPEL might be needed for some packages
        $PKG_INSTALL epel-release
    fi
    
    $PKG_INSTALL $PACKAGES
    
    log_info "System updated and dependencies installed."
}

# ------------------------------------------------------------------------------
# 3. Security Configuration (Firewall & SSH)
# ------------------------------------------------------------------------------
configure_security() {
    log_step "Configuring Security..."
    
    # SSH Port & User Setup
    read -p "Enter new SSH port (default: 2222): " SSH_PORT
    SSH_PORT=${SSH_PORT:-2222}
    
    read -p "Enter new sudo username (default: admin): " VPS_USER
    VPS_USER=${VPS_USER:-admin}
    
    read -s -p "Enter password for $VPS_USER (leave empty to generate): " VPS_PASSWORD
    echo ""
    if [ -z "$VPS_PASSWORD" ]; then
        VPS_PASSWORD=$(openssl rand -base64 12)
        log_info "Generated Password: $VPS_PASSWORD"
    fi
    
    # Export for sub-scripts
    export SSH_PORT VPS_USER VPS_PASSWORD
    
    # Run helper script for user/ssh setup (it uses standard linux commands)
    chmod +x scripts/setup_user_ssh.sh
    ./scripts/setup_user_ssh.sh
    
    # Configure Firewall
    if [[ "$FIREWALL" == "ufw" ]]; then
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow "$SSH_PORT"/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 443/udp
        ufw allow 8000/tcp
        ufw allow 8080/tcp
        ufw allow 51820/udp
        echo "y" | ufw enable
        
    elif [[ "$FIREWALL" == "firewalld" ]]; then
        systemctl enable --now firewalld
        firewall-cmd --permanent --add-port="$SSH_PORT"/tcp
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --permanent --add-port=443/udp
        firewall-cmd --permanent --add-port=8000/tcp
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=51820/udp
        firewall-cmd --reload
    fi
    
    log_info "Firewall configured."
}

# ------------------------------------------------------------------------------
# 4. Install Docker
# ------------------------------------------------------------------------------
install_docker() {
    log_step "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker already installed."
    else
        if [[ "$PKG_MANAGER" == "apt-get" ]]; then
            mkdir -p /etc/apt/keyrings
            if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            fi
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            
        elif [[ "$PKG_MANAGER" == "dnf" ]]; then
            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            systemctl start docker
            systemctl enable docker
        fi
        log_info "Docker installed."
    fi

    # Determine Docker Compose command
    if docker compose version &> /dev/null; then
        export COMPOSE_CMD="docker compose"
        log_info "Using 'docker compose' (plugin)"
    elif command -v docker-compose &> /dev/null; then
        export COMPOSE_CMD="docker-compose"
        log_info "Using 'docker-compose' (standalone)"
    else
        log_warn "Docker Compose not found. Attempting standalone installation..."
        curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        if command -v docker-compose &> /dev/null; then
            export COMPOSE_CMD="docker-compose"
            log_info "Standalone Docker Compose installed."
        else
            log_error "Failed to install Docker Compose."
            exit 1
        fi
    fi
}

# ------------------------------------------------------------------------------
# 5. Project Setup
# ------------------------------------------------------------------------------
setup_project() {
    log_step "Setting up Project..."

    # Check for source code presence
    if [ ! -d "blitz_source" ] || [ -z "$(ls -A blitz_source)" ]; then
        log_error "Directory 'blitz_source' is missing or empty!"
        log_error "Please upload the source code to this directory before deploying."
        log_error "Example: scp -r blitz_source/ root@your-server-ip:$(pwd)/"
        exit 1
    fi
    
    # Host WireGuard Setup
    if [ ! -f "/etc/wireguard/wg0.conf" ]; then
        chmod +x scripts/setup-wireguard.sh
        ./scripts/setup-wireguard.sh
    fi
    
    # Hysteria2 & Blitz Setup
    chmod +x setup_hysteria2.sh
    # Pass COMPOSE_CMD to setup script if it supports it, or rely on it detecting
    ./setup_hysteria2.sh
    
    # Start Services
    log_step "Starting Services..."
    $COMPOSE_CMD up -d
    
    if [ $? -ne 0 ]; then
        log_error "Failed to start services with $COMPOSE_CMD up -d"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root"
        exit 1
    fi

    log_info "Starting Master Deployment Script..."
    
    detect_os
    prepare_system
    configure_security
    install_docker
    setup_project
    
    log_step "Verification..."
    if $COMPOSE_CMD ps | grep -q "Up"; then
         log_info "Services are running."
         $COMPOSE_CMD ps
    else
         log_warn "Services might not be running correctly."
         $COMPOSE_CMD ps
    fi
    
    log_info "Deployment Finished Successfully!"
    log_info "Log saved to $LOG_FILE"
}

main "$@"
