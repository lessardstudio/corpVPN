# Corporate VPN Gateway - Hysteria2 Deployment Guide

## Overview
This guide provides step-by-step instructions for deploying the Corporate VPN Gateway with Hysteria2 protocol, offering superior anti-censorship capabilities and performance.

## Architecture Changes

### Protocol Migration: VLESS → Hysteria2
- **Better Anti-Censorship**: Hysteria2 uses UDP with advanced obfuscation
- **Improved Performance**: Native UDP support for faster connections
- **Enhanced Security**: ChaCha20-Poly1305 encryption
- **Corporate Integration**: Seamless WireGuard tunnel integration

## Quick Start

### 1. Prerequisites
```bash
# System requirements
- Ubuntu 24.04 LTS (Recommended)
- Docker 20.10+
- Docker Compose 2.0+
- 2GB RAM minimum
- 10GB disk space

# Network requirements
- Public IP address
- UDP port 443 open
- TCP port 8000 open (admin panel)
```

### 2. VPS Deployment (Ubuntu 24.04)

We provide a comprehensive deployment suite for Ubuntu 24.04 VPS.

#### Step 1: Transfer Files to VPS
Copy the entire project directory to your VPS:
```bash
scp -r corp/ root@your-vps-ip:/opt/corp
```
If you cannot use scp, clone from GitHub directly on the VPS:
```bash
git clone https://github.com/your-org/corp-vpn.git /opt/corp
```

#### Step 2: Run Deployment Script
Connect to your VPS and run the master deployment script:
```bash
ssh root@your-vps-ip
cd /opt/corp
chmod +x scripts/deploy_vps.sh
./scripts/deploy_vps.sh
```

This script will interactively ask for:
- New sudo username
- Password for the new user
- Custom SSH port (default: 2222)

And then automatically:
1. Update system and install dependencies
2. Configure UFW Firewall and Fail2ban
3. Create the new user and harden SSH (disable root login, change port)
4. Setup Host-based WireGuard
5. Generate Hysteria2 configurations
6. Start all services

> **IMPORTANT**: After deployment, your SSH port will be changed. Connect using:
> `ssh -p <NEW_PORT> <NEW_USER>@your-vps-ip`

#### Step 3: Post-Deployment
After deployment, configure SSL and environment variables:
```bash
# Set your domain
export DOMAIN=vpn.your-company.com
export EMAIL=admin@your-company.com

# Setup Let's Encrypt SSL
./scripts/setup-ssl.sh production

# Update secrets in .env
nano .env
# Restart services
docker-compose up -d
```

### 3. Manual Configuration (Legacy)

#### Environment Variables
```bash
# Required configuration
cat > .env <<EOF
DOMAIN=your-domain.com
BLITZ_ADMIN_PASSWORD=your-secure-password
TELEGRAM_BOT_TOKEN=your-bot-token
CORPORATE_SECRET=your-corporate-secret
WIREGUARD_ENDPOINT=office.example.com:51820
WIREGUARD_PUBLIC_KEY=office-wireguard-public-key
EOF
```

#### SSL Certificates
```bash
# For production (Let's Encrypt)
export DOMAIN=your-domain.com
export EMAIL=admin@your-domain.com
./scripts/setup-ssl.sh production

# For testing (self-signed)
./scripts/setup-ssl.sh
```

#### WireGuard Setup
```bash
# Generate WireGuard keys and configure tunnel
./scripts/setup-wireguard.sh

# Provide VPS public key to office network admin
cat wireguard/config/public.key
```

## Service Configuration

### Blitz Panel (Hysteria2 Management)
- **URL**: https://your-domain.com:8000
- **Username**: admin
- **Password**: From BLITZ_ADMIN_PASSWORD

### Hysteria2 Server
- **Port**: 443 (UDP/TCP)
- **Protocol**: Hysteria2
- **Encryption**: ChaCha20-Poly1305
- **Obfuscation**: Proxy masquerade (dl.google.com)

### Automation API
- **URL**: http://localhost:8080
- **Endpoints**:
  - `POST /access/grant` - Create VPN user
  - `GET /user/{id}/config` - Get user configuration
  - `POST /user/{id}/deactivate` - Deactivate user

## Client Configuration

### Hiddify (Recommended)
1. Download Hiddify from [hiddify.com](https://hiddify.com)
2. Import configuration via QR code or subscription URL
3. Enable "Corporate Mode" for split tunneling

### Sing-Box
1. Download Sing-Box client
2. Import hysteria2 configuration
3. Corporate networks route through VPN

### Manual Configuration
```json
{
  "server": "your-domain.com:443",
  "auth": "your-auth-key",
  "tls": {
    "sni": "dl.google.com",
    "insecure": false
  },
  "masquerade": {
    "type": "proxy",
    "proxy": {
      "url": "https://dl.google.com",
      "rewriteHost": true
    }
  }
}
```

## Network Routing

### Split Tunneling
- **Corporate Networks**: 192.168.0.0/16, 10.0.0.0/8 → VPN
- **Private Networks**: 172.16.0.0/12 → Direct
- **Internet Traffic**: → Direct (bypass VPN)

### Traffic Flow
```
User Device → Hysteria2 (Port 443) → VPS → WireGuard → Office Network
     ↓
Internet Traffic → Direct (bypass VPN)
```

## Security Features

### Anti-Censorship
- UDP protocol with TCP fallback
- TLS masquerading as legitimate traffic
- Domain fronting with Google services
- Packet obfuscation

### Access Control
- Corporate secret authentication
- Telegram 2FA integration
- User deactivation via webhooks
- Traffic monitoring and logging

### Encryption
- ChaCha20-Poly1305 (modern, fast)
- TLS 1.3 for control channel
- Perfect forward secrecy

## Monitoring & Maintenance

### Health Checks
```bash
# Check service status
docker-compose ps

# Test Hysteria2 connectivity
docker-compose exec blitz curl -k https://localhost:8000/health

# Check logs
docker-compose logs -f blitz
docker-compose logs -f automation-service
```

### Traffic Statistics
- Blitz panel: Real-time usage
- API endpoint: `/user/{id}/config` - includes stats
- Database: Historical traffic data

### Backup & Recovery
```bash
# Backup configuration
tar -czf backup-$(date +%Y%m%d).tar.gz configs/ blitz_data/ automation_data/

# Restore from backup
tar -xzf backup-20240120.tar.gz
```

## Troubleshooting

### Connection Issues
1. **Check firewall**: Ensure UDP 443 is open
2. **Verify DNS**: Domain resolves to correct IP
3. **Test locally**: `curl -k https://your-domain:8000/health`
4. **Check certificates**: SSL validity and expiration

### Performance Issues
1. **Bandwidth limits**: Check Blitz configuration
2. **Network congestion**: Monitor traffic patterns
3. **Server resources**: CPU/memory usage
4. **WireGuard tunnel**: Office network capacity

### Authentication Issues
1. **Corporate secret**: Verify API authentication
2. **Telegram bot**: Check token and permissions
3. **User status**: Ensure user is active in database
4. **Webhook delivery**: Check HR system integration

## Migration from VLESS

### Automatic Migration
```bash
# Run migration script
./scripts/migrate_to_hysteria2.sh

# Verify migration
curl -X POST http://localhost:8080/access/grant \
  -H "X-Corporate-Secret: your-secret" \
  -H "Content-Type: application/json" \
  -d '{"corporate_id": "test123"}'
```

### Manual Migration Steps
1. Stop VLESS services: `docker-compose down`
2. Backup data: `cp -r marzban_data marzban_backup`
3. Update docker-compose.yml for Hysteria2
4. Start new services: `docker-compose up -d`
5. Test client connections

## Support & Resources

### Documentation
- [Blitz Panel Documentation](https://github.com/ReturnFI/Blitz)
- [Hysteria2 Protocol Specification](https://v2.hysteria.network)
- [WireGuard Configuration Guide](https://www.wireguard.com)

### Community
- Telegram: @CorporateVPNSupport
- GitHub Issues: [Project Repository](https://github.com/your-repo)
- Email: support@your-company.com

### Professional Services
- Installation assistance
- Custom configuration
- Performance optimization
- 24/7 monitoring setup
