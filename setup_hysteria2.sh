#!/bin/bash

# Hysteria2 Migration Setup Script for Corporate VPN Gateway
# This script migrates from VLESS to Hysteria2 protocol

set -e

echo "🚀 Starting Hysteria2 Migration for Corporate VPN Gateway"
echo "=================================================="

# Configuration variables
DOMAIN="${DOMAIN:-your-domain.com}"
BLITZ_ADMIN_PASSWORD="${BLITZ_ADMIN_PASSWORD:-changeme123}"
BLITZ_SECRET_KEY="${BLITZ_SECRET_KEY:-$(openssl rand -hex 32)}"
HYSTERIA2_PASSWORD="${HYSTERIA2_PASSWORD:-$(openssl rand -hex 16)}"
WIREGUARD_ENDPOINT="${WIREGUARD_ENDPOINT:-office.example.com:51820}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if domain is set
    if [ "$DOMAIN" = "your-domain.com" ]; then
        log_warn "DOMAIN is not set. Using default value. Please update .env file with your actual domain."
    fi
    
    log_info "Prerequisites check completed."
}

# Create necessary directories
setup_directories() {
    log_info "Setting up directories..."
    
    mkdir -p {blitz_data,configs,wireguard/config,automation_data,scripts}
    mkdir -p /var/log/{blitz,hysteria2}
    
    log_info "Directories created."
}

# Generate SSL certificates
setup_ssl_certificates() {
    log_info "Setting up SSL certificates..."
    
    CERT_DIR="configs/ssl"
    mkdir -p "$CERT_DIR"
    
    # Generate self-signed certificate for testing
    if [ ! -f "$CERT_DIR/server.crt" ]; then
        log_info "Generating self-signed SSL certificate..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$CERT_DIR/server.key" \
            -out "$CERT_DIR/server.crt" \
            -subj "/C=RU/ST=Moscow/L=Moscow/O=Corporate/CN=$DOMAIN"
        
        chmod 600 "$CERT_DIR/server.key"
        chmod 644 "$CERT_DIR/server.crt"
        
        log_info "Self-signed certificate generated."
    else
        log_info "SSL certificates already exist."
    fi
}

# Create Blitz configuration
create_blitz_config() {
    log_info "Creating Blitz configuration..."
    
    cat > configs/blitz.env <<EOF
# Blitz Panel Configuration
BLITZ_ADMIN_USERNAME=admin
BLITZ_ADMIN_PASSWORD=$BLITZ_ADMIN_PASSWORD
BLITZ_SECRET_KEY=$BLITZ_SECRET_KEY

# Hysteria2 Configuration
HYSTERIA2_ENABLED=true
HYSTERIA2_PORT=443
HYSTERIA2_DOMAIN=$DOMAIN
HYSTERIA2_PASSWORD=$HYSTERIA2_PASSWORD

# Network Configuration
CORPORATE_NETWORKS="192.168.0.0/16,10.0.0.0/8"
WIREGUARD_ENDPOINT=$WIREGUARD_ENDPOINT

# Security Configuration
ENABLE_ACL=true
BLOCK_PRIVATE_IPS=true
ALLOW_CORPORATE_ONLY=false

# Performance Configuration
MAX_CONNECTIONS=1000
BANDWIDTH_UP=100mbps
BANDWIDTH_DOWN=100mbps
UDP_IDLE_TIMEOUT=30s

# Logging Configuration
LOG_LEVEL=info
ACCESS_LOG=/var/log/blitz/access.log
ERROR_LOG=/var/log/blitz/error.log

# Masquerade Configuration (Anti-censorship)
MASQUERADE_TYPE=proxy
MASQUERADE_URL=https://dl.google.com
MASQUERADE_REWRITE_HOST=true
EOF

    log_info "Blitz configuration created."
}

# Create Hysteria2 server configuration
create_hysteria2_config() {
    log_info "Creating Hysteria2 server configuration..."
    
    cat > configs/hysteria2_server.json <<EOF
{
  "listen": ":443",
  "tls": {
    "cert": "/etc/blitz/ssl/server.crt",
    "key": "/etc/blitz/ssl/server.key"
  },
  "auth": {
    "type": "password",
    "password": "$HYSTERIA2_PASSWORD"
  },
  "masquerade": {
    "type": "proxy",
    "proxy": {
      "url": "https://dl.google.com",
      "rewriteHost": true
    }
  },
  "bandwidth": {
    "up": "100 mbps",
    "down": "100 mbps"
  },
  "ignoreClientBandwidth": false,
  "disableUDP": false,
  "udpIdleTimeout": "30s",
  "acl": {
    "inline": [
      "# Corporate networks - allow direct access",
      "192.168.0.0/16",
      "10.0.0.0/8",
      "# Block other private networks",
      "!172.16.0.0/12",
      "# Allow all other traffic through VPN",
      "*"
    ]
  },
  "outbounds": [
    {
      "name": "office-network",
      "type": "direct",
      "direct": {
        "mode": ""
      }
    },
    {
      "name": "internet",
      "type": "direct",
      "direct": {
        "mode": ""
      }
    }
  ],
  "trafficStats": {
    "listen": "127.0.0.1:9090"
  }
}
EOF

    log_info "Hysteria2 server configuration created."
}

# Create WireGuard configuration
create_wireguard_config() {
    log_info "WireGuard configuration is handled by scripts/setup-wireguard.sh (Host Mode)"
    
    # Check if host keys exist (if running as root)
    if [ -f "/etc/wireguard/public.key" ]; then
        VPS_PUBLIC_KEY=$(cat /etc/wireguard/public.key)
        log_info "Found Host WireGuard Public Key: $VPS_PUBLIC_KEY"
    else
        log_warn "Host WireGuard keys not found. Please run scripts/setup-wireguard.sh first."
        VPS_PUBLIC_KEY="run_setup_wireguard_sh_first"
    fi
}

# Update environment file
update_env_file() {
    log_info "Updating .env file..."
    
    cat > .env <<EOF
# Blitz Panel Configuration
BLITZ_ADMIN_PASSWORD=$BLITZ_ADMIN_PASSWORD
BLITZ_SECRET_KEY=$BLITZ_SECRET_KEY
HYSTERIA2_PASSWORD=$HYSTERIA2_PASSWORD

# Domain Configuration
DOMAIN=$DOMAIN

# WireGuard Configuration
WIREGUARD_ENDPOINT=$WIREGUARD_ENDPOINT
WIREGUARD_PUBLIC_KEY=$VPS_PUBLIC_KEY

# Corporate Security
CORPORATE_SECRET=$(openssl rand -hex 16)
WEBHOOK_SECRET=$(openssl rand -hex 16)

# Telegram Configuration
TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here

# Database Configuration
DB_PATH=/app/data/users.db
EOF

    log_info ".env file updated. Please update TELEGRAM_BOT_TOKEN with your actual token."
}

# Create client configuration templates
create_client_templates() {
    log_info "Creating client configuration templates..."
    
    # Hiddify template
    cat > configs/hysteria2_hiddify.json <<EOF
{
  "server": "$DOMAIN:443",
  "auth": "{auth_key}",
  "tls": {
    "sni": "dl.google.com",
    "insecure": false
  },
  "bandwidth": {
    "up": "100 mbps",
    "down": "100 mbps"
  },
  "masquerade": {
    "type": "proxy",
    "proxy": {
      "url": "https://dl.google.com",
      "rewriteHost": true
    }
  },
  "acl": {
    "inline": [
      "192.168.0.0/16",
      "10.0.0.0/8",
      "!172.16.0.0/12",
      "*"
    ]
  }
}
EOF

    # Sing-Box template
    cat > configs/singbox_hysteria2.json <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "tun",
      "inet4_address": "172.19.0.1/30",
      "auto_route": true,
      "strict_route": false,
      "endpoint_independent_nat": true,
      "stack": "system"
    }
  ],
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "corporate-vpn",
      "server": "$DOMAIN",
      "server_port": 443,
      "up_mbps": 100,
      "down_mbps": 100,
      "password": "{auth_key}",
      "tls": {
        "enabled": true,
        "server_name": "dl.google.com",
        "insecure": false
      },
      "masquerade": {
        "type": "proxy",
        "proxy": {
          "url": "https://dl.google.com",
          "rewrite_host": true
        }
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "ip_cidr": ["192.168.0.0/16", "10.0.0.0/8"],
        "outbound": "corporate-vpn"
      },
      {
        "ip_cidr": ["172.16.0.0/12", "127.0.0.0/8"],
        "outbound": "direct"
      }
    ],
    "final": "direct",
    "auto_detect_interface": true
  }
}
EOF

    log_info "Client configuration templates created."
}

# Create migration script
create_migration_script() {
    log_info "Creating migration script..."
    
    cat > scripts/migrate_to_hysteria2.sh <<EOF
#!/bin/bash

# Migration script from VLESS to Hysteria2
# Run this script to migrate existing users

set -e

echo "🔄 Starting migration from VLESS to Hysteria2..."

# Stop existing services
docker-compose down

# Backup existing data
echo "💾 Creating backup..."
cp -r marzban_data marzban_data_backup_$(date +%Y%m%d_%H%M%S)

# Pull new images
echo "📦 Pulling new images..."
docker-compose pull

# Start new services
echo "🚀 Starting Hysteria2 services..."
docker-compose up -d

# Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 30

# Test connectivity
echo "🧪 Testing Hysteria2 connectivity..."
docker-compose exec blitz curl -k https://localhost:8000/health || echo "Health check failed"

echo "✅ Migration completed successfully!"
echo ""
echo "Next steps:"
echo "1. Update your .env file with actual values"
echo "2. Configure WireGuard with your office network"
echo "3. Test client connections"
echo "4. Update DNS records to point to your server"
EOF

    chmod +x scripts/migrate_to_hysteria2.sh
    log_info "Migration script created."
}

# Main execution
main() {
    log_info "Starting Hysteria2 setup for Corporate VPN Gateway..."
    
    check_prerequisites
    setup_directories
    setup_ssl_certificates
    create_blitz_config
    create_hysteria2_config
    create_wireguard_config
    update_env_file
    create_client_templates
    create_migration_script
    
    log_info "✅ Hysteria2 setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Update .env file with your actual values"
    echo "2. Configure WireGuard with your office network administrator"
    echo "3. Run: ./scripts/migrate_to_hysteria2.sh"
    echo "4. Test client connections"
    echo ""
    echo "Important information:"
    echo "- Blitz Admin Password: $BLITZ_ADMIN_PASSWORD"
    echo "- Hysteria2 Password: $HYSTERIA2_PASSWORD"
    echo "- WireGuard VPS Public Key: $VPS_PUBLIC_KEY"
    echo ""
    echo "Access URLs:"
    echo "- Blitz Panel: https://$DOMAIN:8000"
    echo "- Hysteria2 Server: $DOMAIN:443"
    echo "- Automation API: http://localhost:8080"
}

# Run main function
main "$@"