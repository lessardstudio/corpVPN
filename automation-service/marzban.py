import httpx
from typing import Optional, Dict, Any
import logging

logger = logging.getLogger(__name__)

class MarzbanClient:
    def __init__(self, base_url: str, api_token: str):
        self.base_url = base_url.rstrip('/')
        self.headers = {
            # Blitz expects exact token match, no Bearer prefix
            "Authorization": f"{api_token}",
            "Content-Type": "application/json"
        }

    async def create_user(self, username: str, proxies: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Create a user in Marzban.
        """
        url = f"{self.base_url}/api/user"
        # Default proxy settings if none provided
        # Marzban usually creates default proxies if empty, but we might need to specify protocols
        # specific to VLESS Reality.
        # For now, we send a minimal payload.
        payload = {
            "username": username,
            "proxies": proxies or {"vless": {}}, # Enable VLESS by default
            "expire": 0, # Unlimited
            "data_limit": 0, # Unlimited
            "status": "active"
        }
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(url, json=payload, headers=self.headers)
                response.raise_for_status()
                return response.json()
            except httpx.HTTPStatusError as e:
                logger.error(f"Marzban API Error: {e.response.text}")
                raise

    async def get_user(self, username: str) -> Optional[Dict[str, Any]]:
        url = f"{self.base_url}/api/user/{username}"
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(url, headers=self.headers)
                if response.status_code == 404:
                    return None
                response.raise_for_status()
                return response.json()
            except httpx.HTTPStatusError as e:
                logger.error(f"Marzban API Error: {e.response.text}")
                raise
