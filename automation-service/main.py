from fastapi import FastAPI, HTTPException, Header, Depends
from contextlib import asynccontextmanager
import asyncio
import logging
from typing import Optional
from pydantic import BaseModel
import qrcode
import io
import base64

from config import get_settings
from database import Database
from blitz_client import BlitzClient
from telegram_2fa import Telegram2FA
from monitor import HealthMonitor

from logger import setup_logging

# Configure logging
setup_logging()
logger = logging.getLogger(__name__)

settings = get_settings()
db = Database(settings.DB_PATH)
blitz = BlitzClient(
    settings.BLITZ_API_URL,
    settings.BLITZ_SECRET_KEY
)
telegram_2fa = Telegram2FA()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Initializing Database...")
    await db.init_db()
    
    logger.info("Starting Telegram Bot...")
    # Run bot in background
    asyncio.create_task(telegram_2fa.start_bot())
    logger.info("Starting Health Monitor...")
    monitor = HealthMonitor(db, telegram_2fa)
    await monitor.start()
    
    yield
    
    # Shutdown
    logger.info("Shutting down...")

app = FastAPI(lifespan=lifespan)

class GrantAccessRequest(BaseModel):
    corporate_id: str

class GrantAccessResponse(BaseModel):
    corporate_id: str
    username: str
    subscription_url: str
    hy2_url: str
    qr_code: str

class UserConfigResponse(BaseModel):
    corporate_id: str
    username: str
    hy2_url: str
    subscription_url: str
    qr_code: str
    traffic_stats: dict

@app.post("/access/grant", response_model=GrantAccessResponse)
async def grant_access(
    request: GrantAccessRequest,
    x_corporate_secret: str = Header(..., alias="X-Corporate-Secret")
):
    if x_corporate_secret != settings.CORPORATE_SECRET:
        raise HTTPException(status_code=403, detail="Invalid corporate secret")

    corporate_id = request.corporate_id
    username = f"corp_{corporate_id}"
    
    # Check if user already exists in DB
    existing_user = await db.get_user(corporate_id)
    if existing_user:
        # Generate QR code for existing user
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(existing_user.get("hy2_url", ""))
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        buffer = io.BytesIO()
        img.save(buffer, format="PNG")
        qr_code = base64.b64encode(buffer.getvalue()).decode()
        
        return GrantAccessResponse(
            corporate_id=existing_user["corporate_id"],
            username=existing_user["blitz_username"],
            subscription_url=existing_user["subscription_url"],
            hy2_url=existing_user.get("hy2_url", ""),
            qr_code=qr_code
        )

    # Create Hysteria2 user in Blitz
    try:
        # Check if user exists in Blitz
        user = await blitz.get_user(username)
        if not user:
            created_user = await blitz.create_user(username)
            hy2_auth_key = created_user.get("auth_key")
        else:
            hy2_auth_key = user.get("auth_key")
        
        # Get Hysteria2 configuration
        hy2_url = await blitz.get_hy2_url(username)
        subscription_url = await blitz.get_subscription_url(username)
        if not hy2_auth_key:
            refreshed = await blitz.get_user(username)
            hy2_auth_key = (refreshed or {}).get("auth_key", "")
        
        # Generate QR code
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(hy2_url)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        buffer = io.BytesIO()
        img.save(buffer, format="PNG")
        qr_code = base64.b64encode(buffer.getvalue()).decode()
        
        # Save to DB
        await db.add_user(
            corporate_id=corporate_id,
            blitz_username=username,
            subscription_url=subscription_url,
            hy2_url=hy2_url,
            hy2_auth_key=hy2_auth_key,
        )
        
        return GrantAccessResponse(
            corporate_id=corporate_id,
            username=username,
            subscription_url=subscription_url,
            hy2_url=hy2_url,
            qr_code=qr_code
        )

    except Exception as e:
        logger.error(f"Error granting access: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/user/{corporate_id}/config", response_model=UserConfigResponse)
async def get_user_config(
    corporate_id: str,
    x_corporate_secret: str = Header(..., alias="X-Corporate-Secret")
):
    if x_corporate_secret != settings.CORPORATE_SECRET:
        raise HTTPException(status_code=403, detail="Invalid corporate secret")
    
    user = await db.get_user(corporate_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get traffic stats from Blitz
    try:
        stats = await blitz.get_user_stats(user["blitz_username"])
    except Exception as e:
        logger.error(f"Error getting user stats: {e}")
        stats = {"upload": 0, "download": 0}
    
    # Generate QR code
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(user.get("hy2_url", ""))
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    qr_code = base64.b64encode(buffer.getvalue()).decode()
    
    return UserConfigResponse(
        corporate_id=user["corporate_id"],
            username=user["blitz_username"],
        hy2_url=user.get("hy2_url", ""),
        subscription_url=user["subscription_url"],
        qr_code=qr_code,
        traffic_stats=stats
    )

@app.post("/user/{corporate_id}/deactivate")
async def deactivate_user(
    corporate_id: str,
    x_corporate_secret: str = Header(..., alias="X-Corporate-Secret")
):
    if x_corporate_secret != settings.CORPORATE_SECRET:
        raise HTTPException(status_code=403, detail="Invalid corporate secret")
    
    user = await db.get_user(corporate_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    try:
        # Deactivate in Blitz
        await blitz.update_user_status(user["blitz_username"], False)
        
        # Deactivate in database
        await db.deactivate_user(corporate_id)
        
        return {"status": "deactivated", "corporate_id": corporate_id}
        
    except Exception as e:
        logger.error(f"Error deactivating user: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "automation-service",
        "protocol": "hysteria2",
        "timestamp": "2024-01-20T12:00:00Z"
    }

# Include webhook routes
from webhooks import router as webhook_router
app.include_router(webhook_router)
