# Corporate VPN Gateway

A secure, high-performance corporate VPN gateway using Hysteria2 protocol, WireGuard tunneling, and Blitz Panel management.

## 🚀 Features
- **Hysteria2 Protocol**: Advanced anti-censorship and high performance over UDP.
- **Corporate Integration**: Secure WireGuard tunnel to office networks.
- **Automation**: Telegram bot 2FA, HR webhook integration, and automated user provisioning.
- **Management**: Blitz Panel for user and bandwidth management.

## 📋 Prerequisites
- **Server**: Ubuntu 22.04+ (Recommended), Debian 11+, or CentOS 9.
- **Docker**: Docker Engine 24.0+ and Docker Compose plugin.
- **Domain**: A domain name pointing to your server IP.

## 🛠 Deployment Options

### Option A: Full Docker Stack (Recommended)
This runs all services (Blitz, MongoDB, Automation Service) in containers. Easiest to manage.

1.  **Clone & Prepare**:
    ```bash
    git clone https://github.com/your-org/corp-vpn.git
    cd corp-vpn
    ```

2.  **Configure**:
    Create `.env` file from example:
    ```bash
    cp .env.example .env
    nano .env
    ```
    *Fill in your domain and secrets.*

3.  **Deploy**:
    ```bash
    docker-compose up -d --build
    ```

    Single-command startup builds images if needed, initializes databases (Mongo and SQLite via app lifespan), starts Telegram bot, and wires service dependencies automatically.

4.  **Access**:
    -   **Blitz Admin**: `http://YOUR_DOMAIN:8000/blitz/login`
    -   **Telegram Bot**: Start the bot `@YourBotName`

### Option B: Manual Blitz + Docker Automation
Runs Blitz Panel directly on the host (systemd) for maximum performance, while keeping automation isolated.

1.  **Install Blitz Manually**:
    ```bash
    chmod +x scripts/install_manual_blitz.sh
    ./scripts/install_manual_blitz.sh
    ```

2.  **Run Automation Service**:
    Use the manual configuration file:
    ```bash
    docker-compose -f docker-compose.manual-blitz.yml up -d --build
    ```

## 📂 Project Structure
-   `automation-service/`: FastAPI application and Telegram bot.
-   `blitz_docker/`: Docker configuration for Blitz Panel.
-   `blitz_source/`: Source code for Blitz Panel (submodule).
-   `configs/`: Configuration templates.
-   `scripts/`: Deployment and maintenance scripts.

## 🔒 Security & Secrets
-   **NEVER** commit `.env` files.
-   **Rotate** default passwords immediately after installation.
-   **Firewall**: Ensure ports `8000` (TCP), `443` (TCP/UDP), and `8080` (TCP) are secured.

## 📚 Documentation
-   [Architecture](ARCHITECTURE.md)
-   [Deployment Guide](DEPLOYMENT.md)
 -   [Admin Guide](ADMIN_GUIDE.md)
 -   [ID Policy](ID_POLICY.md)

## ⚙️ .env Variables
Required:
- `DOMAIN` — public domain for URLs
- `BLITZ_ADMIN_PASSWORD` — admin password for Blitz
- `BLITZ_SECRET_KEY` — shared secret for API/webhooks
- `TELEGRAM_BOT_TOKEN` — bot token from @BotFather
- `CORPORATE_SECRET` — header `X-Corporate-Secret` value for protected endpoints

Optional:
- `ADMIN_TELEGRAM_IDS` — comma-separated Telegram IDs with admin rights in bot
- `WEBHOOK_SECRET` — HMAC secret for webhook signatures
- `HYSTERIA2_PORT` — Hysteria listen port (default 443)

Use [.env.example](file:///c:/Users/User/Desktop/corp/.env.example) as a template.
