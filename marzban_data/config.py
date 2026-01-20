# Marzban Configuration
# This file contains basic configuration for Marzban panel

# Database configuration
SQLALCHEMY_DATABASE_URL = "sqlite:///var/lib/marzban/db.sqlite3"

# Security settings
SECRET_KEY = "your-secret-key-change-this"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days

# Xray configuration
XRAY_JSON = "/var/lib/marzban/xray_config.json"
XRAY_EXECUTABLE_PATH = "/usr/local/bin/xray"
XRAY_ASSETS_PATH = "/usr/local/share/xray"
XRAY_CONFIGS_TEMPLATE_PATH = "/var/lib/marzban/templates"

# Subscription settings
SUBSCRIPTION_URL_PREFIX = ""
SUBSCRIPTION_USER_AGENT = "Hiddify/1.0"

# Telegram settings (optional)
TELEGRAM_API_TOKEN = ""
TELEGRAM_ADMIN_ID = ""

# Panel settings
DEBUG = False
UVICORN_HOST = "0.0.0.0"
UVICORN_PORT = 8000

# Traffic limit settings
DEFAULT_TOTAL_GB = 0  # 0 means unlimited
DEFAULT_EXPIRE_DAYS = 0  # 0 means unlimited
DEFAULT_SERVICES = ["vless"]