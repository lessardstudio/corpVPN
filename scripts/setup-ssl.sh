#!/bin/bash

# SSL/TLS certificate setup script for Corporate VPN Gateway
# This script sets up SSL certificates for secure connections

set -e

echo "Setting up SSL/TLS certificates..."

# Configuration variables
DOMAIN="${DOMAIN:-your-domain.com}"
EMAIL="${EMAIL:-admin@your-domain.com}"
CERT_DIR="/var/lib/marzban/ssl"

# Create certificate directory
mkdir -p "$CERT_DIR"

# Function to generate self-signed certificate (for testing)
generate_self_signed() {
    echo "Generating self-signed certificate for testing..."
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$CERT_DIR/marzban.key" \
        -out "$CERT_DIR/marzban.crt" \
        -subj "/C=RU/ST=Moscow/L=Moscow/O=Corporate/CN=$DOMAIN"
    
    echo "Self-signed certificate generated successfully"
}

# Function to get Let's Encrypt certificate (for production)
get_letsencrypt_cert() {
    echo "Getting Let's Encrypt certificate for $DOMAIN..."
    
    # Install certbot if not available
    if ! command -v certbot &> /dev/null; then
        echo "Installing certbot..."
        apt-get update
        apt-get install -y certbot
    fi
    
    # Get certificate
    certbot certonly --standalone \
        --preferred-challenges http \
        -d "$DOMAIN" \
        --email "$EMAIL" \
        --agree-tos \
        --non-interactive
    
    # Copy certificates to Marzban directory
    cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_DIR/marzban.crt"
    cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$CERT_DIR/marzban.key"
    
    echo "Let's Encrypt certificate obtained successfully"
}

# Function to setup automatic renewal
setup_auto_renewal() {
    echo "Setting up automatic certificate renewal..."
    
    # Create renewal script
    cat > "$CERT_DIR/renew-cert.sh" <<EOF
#!/bin/bash
# Auto-renewal script for Let's Encrypt certificates

certbot renew --quiet --no-self-upgrade

# Copy renewed certificates to Marzban directory
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_DIR/marzban.crt"
    cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$CERT_DIR/marzban.key"
    
    # Restart Marzban to pick up new certificates
    docker-compose restart marzban
fi
EOF
    
    chmod +x "$CERT_DIR/renew-cert.sh"
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "0 2 * * * $CERT_DIR/renew-cert.sh") | crontab -
    
    echo "Automatic renewal configured"
}

# Main setup logic
if [ "$1" == "production" ]; then
    if [ -z "$DOMAIN" ] || [ "$DOMAIN" == "your-domain.com" ]; then
        echo "Error: Please set DOMAIN environment variable for production"
        exit 1
    fi
    
    get_letsencrypt_cert
    setup_auto_renewal
else
    generate_self_signed
fi

# Set proper permissions
chmod 600 "$CERT_DIR/marzban.key"
chmod 644 "$CERT_DIR/marzban.crt"

# Create certificate info file
cat > "$CERT_DIR/cert-info.txt" <<EOF
Certificate Information
========================
Domain: $DOMAIN
Email: $EMAIL
Generated: $(date)
Certificate Type: $([ "$1" == "production" ] && echo "Let's Encrypt" || echo "Self-signed")
Certificate Path: $CERT_DIR/marzban.crt
Private Key Path: $CERT_DIR/marzban.key
EOF

echo "SSL/TLS setup completed!"
echo "Certificate type: $([ "$1" == "production" ] && echo "Let's Encrypt" || echo "Self-signed")"
echo "Certificate path: $CERT_DIR/marzban.crt"
echo "Private key path: $CERT_DIR/marzban.key"
echo ""
echo "For production use, set DOMAIN and EMAIL environment variables and run:"
echo "  DOMAIN=your-domain.com EMAIL=admin@your-domain.com ./setup-ssl.sh production"