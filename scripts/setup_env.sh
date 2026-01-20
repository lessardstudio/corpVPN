#!/bin/bash

# ==============================================================================
# Helper script to generate .env file
# ==============================================================================

ENV_FILE=".env"

if [ -f "$ENV_FILE" ]; then
    echo ".env file already exists. Skipping generation."
    exit 0
fi

echo "Generating .env file..."

# Generate secure secrets
ADMIN_PASS=$(openssl rand -base64 12)
SECRET_KEY=$(openssl rand -hex 32)
CORP_SECRET=$(openssl rand -hex 32)

cat > "$ENV_FILE" <<EOF
# Domain Configuration
DOMAIN=h2.quick-vpn.ru

# Blitz Panel Configuration
BLITZ_ADMIN_PASSWORD=$ADMIN_PASS
BLITZ_SECRET_KEY=$SECRET_KEY

# Telegram Bot Configuration
# REPLACE WITH YOUR ACTUAL BOT TOKEN
TELEGRAM_BOT_TOKEN=123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ

# Corporate API Configuration
CORPORATE_SECRET=$CORP_SECRET
EOF

echo ".env file created successfully!"
echo "Admin Password: $ADMIN_PASS"
echo "Please update TELEGRAM_BOT_TOKEN in .env"
chmod 600 "$ENV_FILE"
