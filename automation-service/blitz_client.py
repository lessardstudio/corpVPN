import httpx
from typing import Optional, Dict, Any
import logging
import secrets

logger = logging.getLogger(__name__)

class BlitzClient:
    """Client for Blitz Panel Hysteria2 management API"""
    
    def __init__(self, base_url: str, api_token: str):
        self.base_url = base_url.rstrip('/')
        self.api_token = api_token

    def _public_base_url(self) -> str:
        return self.base_url[:-4] if self.base_url.endswith("/api") else self.base_url
        
    async def _get_token(self) -> str:
        """Get authentication token from Blitz panel"""
        return self.api_token
                
    async def _make_request(self, method: str, endpoint: str, data: Dict = None) -> Dict[str, Any]:
        """Make authenticated request to Blitz API"""
        token = await self._get_token()
        
        headers = {
            "Authorization": f"{token}",
            "Content-Type": "application/json"
        }
        
        url = f"{self.base_url}{endpoint}"
        
        async with httpx.AsyncClient() as client:
            try:
                if method == "GET":
                    response = await client.get(url, headers=headers)
                elif method == "POST":
                    response = await client.post(url, json=data, headers=headers)
                elif method == "PUT":
                    response = await client.put(url, json=data, headers=headers)
                elif method == "DELETE":
                    response = await client.delete(url, headers=headers)
                else:
                    raise ValueError(f"Unsupported method: {method}")
                    
                response.raise_for_status()
                return response.json() if response.content else {}
                
            except httpx.HTTPStatusError as e:
                logger.error(f"Blitz API error: {e.response.text}")
                raise

    async def create_user(self, username: str, expiry_days: int = 0, data_limit_gb: int = 0) -> Dict[str, Any]:
        """Create Hysteria2 user in Blitz panel"""
        
        # Generate Hysteria2 authentication key
        auth_key = secrets.token_urlsafe(32)
        
        payload = {
            "username": username,
            "auth_key": auth_key,
            "expiry_time": expiry_days * 24 * 60 * 60 if expiry_days > 0 else 0,  # Convert to seconds
            "data_limit": data_limit_gb * 1024 * 1024 * 1024 if data_limit_gb > 0 else 0,  # Convert to bytes
            "enable": True,
            "protocol": "hysteria2"
        }
        
        return await self._make_request("POST", "/users", payload)

    async def get_user(self, username: str) -> Optional[Dict[str, Any]]:
        """Get user information from Blitz panel"""
        try:
            users = await self._make_request("GET", f"/users/{username}")
            return users if users else None
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                return None
            raise

    async def get_user_config(self, username: str) -> Dict[str, Any]:
        """Get Hysteria2 configuration for user"""
        user = await self.get_user(username)
        if not user:
            raise ValueError(f"User {username} not found")
            
        # Generate Hysteria2 configuration
        config = {
            "server": f"{self.base_url.replace('http://', '').replace('https://', '').split(':')[0]}:443",
            "auth": user.get("auth_key", ""),
            "tls": {
                "sni": user.get("sni", "dl.google.com"),
                "insecure": False
            },
            "bandwidth": {
                "up": "100 mbps",
                "down": "100 mbps"
            },
            "masquerade": {
                "type": "proxy",
                "proxy": {
                    "url": "https://dl.google.com",
                    "rewriteHost": True
                }
            },
            "acl": {
                "inline": [
                    "# Corporate networks",
                    "192.168.0.0/16",
                    "10.0.0.0/8",
                    "# Block other private networks",
                    "!172.16.0.0/12",
                    "*"
                ]
            }
        }
        
        return config

    async def delete_user(self, username: str) -> bool:
        """Delete user from Blitz panel"""
        try:
            await self._make_request("DELETE", f"/users/{username}")
            return True
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                return False
            raise

    async def update_user_status(self, username: str, enabled: bool) -> Dict[str, Any]:
        """Enable/disable user"""
        payload = {"enable": enabled}
        return await self._make_request("PUT", f"/users/{username}/status", payload)

    async def get_user_stats(self, username: str) -> Dict[str, Any]:
        """Get user traffic statistics"""
        return await self._make_request("GET", f"/users/{username}/stats")

    async def get_subscription_url(self, username: str) -> str:
        """Get subscription URL for user"""
        return f"{self._public_base_url()}/sub/{username}"

    async def get_hy2_url(self, username: str) -> str:
        """Get Hysteria2 URL for direct connection"""
        user = await self.get_user(username)
        if not user:
            raise ValueError(f"User {username} not found")
            
        server_domain = self.base_url.replace('http://', '').replace('https://', '').split(':')[0]
        auth_key = user.get("auth_key", "")
        
        # Generate hy2:// URL
        return f"hy2://{auth_key}@{server_domain}:443/?sni=dl.google.com&insecure=0#CorporateVPN_{username}"
