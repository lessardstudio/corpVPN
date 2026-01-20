# VPS Deployment Plan (Ubuntu 24.04)

I will create a comprehensive deployment suite for Ubuntu 24.04 VPS that handles system preparation, security hardening, and project installation.

## 1. System Preparation Scripts
I will create `scripts/prepare_vps.sh` to:
- **System Updates**: Update and upgrade all packages.
- **Dependencies**: Install `curl`, `wget`, `git`, `openssl`, `ufw`, `fail2ban`, `unattended-upgrades`.
- **Docker**: Install Docker Engine and Docker Compose V2 from official repositories.
- **WireGuard**: Install WireGuard tools on the host system (for better performance and routing).
- **Kernel Settings**: Enable IP forwarding for VPN routing.

## 2. Security Configuration
I will create `scripts/configure_security.sh` to:
- **Firewall (UFW)**:
  - Allow SSH (22) with rate limiting.
  - Allow Hysteria2 (443 UDP/TCP).
  - Allow Blitz Panel (8000).
  - Allow WireGuard (51820 UDP).
  - Deny other incoming traffic.
- **Fail2ban**: Configure jail for SSH protection.
- **Auto-Updates**: Enable `unattended-upgrades` for security patches.

## 3. Architecture Optimization
I will modify the project structure to use **Host-based WireGuard** instead of Container-based. This is more robust for a Gateway server.
- **Action**: Remove `wireguard` service from `docker-compose.yml`.
- **Action**: Update `setup_hysteria2.sh` to integrate with the host WireGuard setup script.

## 4. Master Deployment Script
I will create `deploy_vps.sh` which:
1. Runs system preparation.
2. Configures security.
3. Sets up Host WireGuard.
4. Generates Hysteria2 configs.
5. Launches the Docker containers.

## 5. Documentation
- Update `DEPLOYMENT.md` with specific instructions for Ubuntu 24.04 VPS deployment.

This ensures a production-ready, secure, and compatible deployment.