# Corporate VPN Gateway

A secure, high-performance corporate VPN gateway using Hysteria2 protocol, WireGuard tunneling, and Blitz Panel management.

## 🚀 Features
- **Hysteria2 Protocol**: Advanced anti-censorship and high performance over UDP.
- **Corporate Integration**: Secure WireGuard tunnel to office networks.
- **Split Tunneling**: Automatic routing of corporate traffic through VPN.
- **Automation**: Telegram bot 2FA, HR webhook integration, and automated user provisioning.
- **Management**: Blitz Panel for user and bandwidth management.

## 🛠 Setup & Installation

### 1. Environment Configuration
The project uses environment variables for configuration. 

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and fill in your secrets:
   ```bash
   nano .env
   ```
   
   **Key variables:**
   - `DOMAIN`: Your VPN server domain.
   - `BLITZ_ADMIN_PASSWORD`: Password for the admin panel.
   - `TELEGRAM_BOT_TOKEN`: Token for the Telegram bot.
   - `WIREGUARD_ENDPOINT`: Address of your office WireGuard gateway.
   - `CORPORATE_SECRET`: Secret key for internal API security.

### 2. Deployment
See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions on Ubuntu VPS.

**Quick Start (Docker):**
```bash
./setup_hysteria2.sh
docker-compose up -d
```

## 📂 Project Structure
- `automation-service/`: FastAPI application and Telegram bot.
- `configs/`: Configuration templates for Blitz, Hysteria2, and clients.
- `scripts/`: Deployment and maintenance scripts.
- `docker-compose.yml`: Main container orchestration file.

## 🔒 Security
- **.env**: Contains sensitive secrets. **NEVER** commit this file to Git.
- **.gitignore**: Configured to exclude sensitive files and data directories.

## 📚 Documentation
- [Architecture](ARCHITECTURE.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Installation Details](INSTALL.MD)
