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

cat > "$ENV_FILE" <<EOF
# Domain Configuration
DOMAIN=h2.quick-vpn.ru

# Blitz Panel Configuration
BLITZ_ADMIN_PASSWORD=qwerty123
BLITZ_SECRET_KEY=token123

# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN=8598682637:AAGk61sxkFuaL-MGUvVHUZk0_uCNX2BaEsM

# Corporate API Configuration
CORPORATE_SECRET=sercetkey123
EOF

echo ".env file created successfully!"
chmod 600 "$ENV_FILE"
