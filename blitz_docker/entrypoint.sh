#!/bin/bash
set -e

# Set defaults
export PORT=${PORT:-8000}
export DOMAIN=${DOMAIN:-localhost}
export DEBUG=${DEBUG:-false}
export ADMIN_USERNAME=${BLITZ_ADMIN_USERNAME:-admin}
export ADMIN_PASSWORD=${BLITZ_ADMIN_PASSWORD:-admin}
export API_TOKEN=${BLITZ_SECRET_KEY:-changeme}
export EXPIRATION_MINUTES=${EXPIRATION_MINUTES:-60}
export ROOT_PATH=${ROOT_PATH:-blitz}
export DECOY_PATH=${DECOY_PATH:-None}

# Generate SHA256 hash for password
ADMIN_PASSWORD_HASH=$(python3 -c "import hashlib; print(hashlib.sha256('$ADMIN_PASSWORD'.encode()).hexdigest())")

# Write .env file for the application
cat <<EOL > /etc/hysteria/core/scripts/webpanel/.env
PORT=$PORT
DOMAIN=$DOMAIN
DEBUG=$DEBUG
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_PASSWORD=$ADMIN_PASSWORD_HASH
API_TOKEN=$API_TOKEN
EXPIRATION_MINUTES=$EXPIRATION_MINUTES
ROOT_PATH=$ROOT_PATH
DECOY_PATH=$DECOY_PATH
EOL

echo "Starting Supervisord (Web Panel + Hysteria2)..."
# Patch Hysteria listen port in config if placeholder is present
if [ -n "${HYSTERIA2_PORT}" ] && [ -f "/etc/hysteria/config.json" ]; then
  sed -i "s/:\$port/:${HYSTERIA2_PORT}/g" /etc/hysteria/config.json
fi
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
