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

# Write .env file for the application
cat <<EOL > /etc/hysteria/core/scripts/webpanel/.env
PORT=$PORT
DOMAIN=$DOMAIN
DEBUG=$DEBUG
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_PASSWORD=$ADMIN_PASSWORD
API_TOKEN=$API_TOKEN
EXPIRATION_MINUTES=$EXPIRATION_MINUTES
ROOT_PATH=$ROOT_PATH
DECOY_PATH=$DECOY_PATH
EOL

echo "Starting Supervisord (Web Panel + Hysteria2)..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
