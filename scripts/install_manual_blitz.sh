#!/bin/bash

# ==============================================================================
# Manual Installation Script for Blitz Panel (Non-Docker)
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

# Check root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root"
    exit 1
fi

# Check for source code
if [ ! -d "blitz_source" ] || [ -z "$(ls -A blitz_source)" ]; then
    log_error "Directory 'blitz_source' is missing or empty!"
    log_error "Please upload the source code to $(pwd)/blitz_source/ before running this script."
    exit 1
fi

# 1. Install System Dependencies
log_info "Installing system dependencies..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
fi

if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    apt-get update
    apt-get install -y python3 python3-pip python3-venv python3-dev git curl wget gnupg
    
    # Install MongoDB (Community Edition)
    if ! command -v mongod &> /dev/null; then
        log_info "Installing MongoDB..."
        curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
           gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
           --dearmor
        echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list
        apt-get update
        apt-get install -y mongodb-org
    fi
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"AlmaLinux"* ]]; then
    dnf install -y python3 python3-pip python3-devel git curl wget
    # MongoDB installation for RHEL-based systems would go here
    # Simplifying for now assuming Ubuntu/Debian as per logs
else
    log_error "Unsupported OS for automatic MongoDB install. Please install MongoDB manually."
fi

# Enable and start MongoDB
systemctl enable mongod
systemctl start mongod

# Install Hysteria2
if ! command -v hysteria &> /dev/null; then
    log_info "Installing Hysteria2..."
    curl -Lo /usr/local/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
    chmod +x /usr/local/bin/hysteria
fi

# 2. Setup Python Environment
log_info "Setting up Python environment..."
INSTALL_DIR="/opt/blitz"
mkdir -p "$INSTALL_DIR"
cp -r blitz_source/* "$INSTALL_DIR/"

cd "$INSTALL_DIR"

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
log_info "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# 3. Patch Configuration
log_info "Configuring application..."

# Create .env file for Blitz
if [ ! -f "$INSTALL_DIR/.env" ]; then
    ADMIN_PASS=$(openssl rand -base64 12)
    API_TOKEN=$(openssl rand -hex 32)
    
    cat <<EOL > "$INSTALL_DIR/.env"
PORT=8000
DOMAIN=h2.quick-vpn.ru
DEBUG=false
ADMIN_USERNAME=admin
ADMIN_PASSWORD=$ADMIN_PASS
API_TOKEN=$API_TOKEN
EXPIRATION_MINUTES=60
ROOT_PATH=blitz
EOL
    log_info "Created .env configuration"
    log_info "Admin Password: $ADMIN_PASS"
    log_info "API Token: $API_TOKEN"
else
    log_info ".env already exists, skipping creation"
fi

# Patch database connection (use localhost instead of mongo service)
DB_FILE="core/scripts/db/database.py"
if [ -f "$DB_FILE" ]; then
    sed -i 's/mongo:27017/localhost:27017/g' "$DB_FILE"
    log_info "Patched $DB_FILE to use localhost"
fi

# Patch app binding (listen on 0.0.0.0)
APP_FILE="core/scripts/webpanel/app.py"
if [ -f "$APP_FILE" ]; then
    sed -i "s/config.bind = \['127.0.0.1:28260'\]/config.bind = ['0.0.0.0:8000']/g" "$APP_FILE"
    log_info "Patched $APP_FILE to bind to 0.0.0.0:8000"
fi

# 4. Create Systemd Service
log_info "Creating Systemd service..."

cat > /etc/systemd/system/blitz.service <<EOF
[Unit]
Description=Blitz Panel
After=network.target mongod.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PYTHONPATH=$INSTALL_DIR/core"
# Load env vars from .env file if it exists, otherwise use defaults
EnvironmentFile=-$INSTALL_DIR/.env
ExecStart=$INSTALL_DIR/venv/bin/python core/scripts/webpanel/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload
systemctl enable blitz
systemctl start blitz

log_info "Blitz Panel installed and started!"
log_info "You can check status with: systemctl status blitz"
