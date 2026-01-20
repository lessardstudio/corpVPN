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
export ADMIN_PASSWORD=$ADMIN_PASSWORD_HASH

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
# Ensure TLS material exists for Hysteria2 server config (self-signed fallback)
mkdir -p /etc/blitz/ssl
if [ ! -f "/etc/blitz/ssl/server.crt" ] || [ ! -f "/etc/blitz/ssl/server.key" ]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout /etc/blitz/ssl/server.key \
    -out /etc/blitz/ssl/server.crt \
    -subj "/CN=${DOMAIN}"
fi

# Patch default Blitz config.json placeholders to real cert/key paths
if [ -f "/etc/hysteria/config.json" ]; then
  sed -i "s|\"cert\": \"/path/to/ca.crt\"|\"cert\": \"/etc/blitz/ssl/server.crt\"|g" /etc/hysteria/config.json
  sed -i "s|\"key\": \"/path/to/ca.key\"|\"key\": \"/etc/blitz/ssl/server.key\"|g" /etc/hysteria/config.json
  python3 - <<'PY'
import json

p = "/etc/hysteria/config.json"
with open(p, "r", encoding="utf-8") as f:
    d = json.load(f)

changed = False
for ob in d.get("outbounds") or []:
    if not isinstance(ob, dict):
        continue
    direct = ob.get("direct")
    if isinstance(direct, dict) and isinstance(direct.get("bindDevice"), str) and direct["bindDevice"].startswith("$"):
        direct.pop("bindDevice", None)
        changed = True

with open(p, "w", encoding="utf-8") as f:
    json.dump(d, f, ensure_ascii=False, indent=2)

print("Patched config.json bindDevice placeholders" if changed else "config.json bindDevice ok")
PY
fi

# Ensure GeoIP/GeoSite databases exist (required by default ACL rules)
if [ -f "/etc/hysteria/config.json" ] && grep -q "geosite:ir" /etc/hysteria/config.json; then
  curl -fsSL -o /etc/hysteria/geosite.dat https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geosite.dat
  curl -fsSL -o /etc/hysteria/geoip.dat https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geoip.dat
fi

# Ensure supervisor control socket path exists for restart scripts
mkdir -p /var/run
rm -f /var/run/supervisor.sock
# Patch Hysteria listen port in config if placeholder is present
if [ -n "${HYSTERIA2_PORT}" ] && [ -f "/etc/hysteria/config.json" ]; then
  sed -i "s/:\$port/:${HYSTERIA2_PORT}/g" /etc/hysteria/config.json
fi
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
