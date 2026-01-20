from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    # Blitz Panel Configuration
    BLITZ_API_URL: str = "http://blitz:8000/api"
    BLITZ_ADMIN_USERNAME: str = "admin"
    BLITZ_ADMIN_PASSWORD: str
    BLITZ_SECRET_KEY: str = "your-secret-key-here"
    
    # Telegram Configuration
    TELEGRAM_BOT_TOKEN: str
    ADMIN_TELEGRAM_IDS: str = ""
    
    # Corporate Security
    CORPORATE_SECRET: str
    WEBHOOK_SECRET: str = "your-webhook-secret"
    
    # Domain Configuration
    DOMAIN: str = "your-domain.com"
    
    # Database Configuration
    DB_PATH: str = "/app/data/users.db"
    
    # Hysteria2 Configuration
    HYSTERIA2_PORT: int = 443
    HYSTERIA2_SERVER: str = "your-domain.com:443"
    
    # WireGuard Configuration
    WIREGUARD_ENDPOINT: str = "office.example.com:51820"
    WIREGUARD_PUBLIC_KEY: str = "your-wireguard-public-key"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

@lru_cache()
def get_settings():
    return Settings()
