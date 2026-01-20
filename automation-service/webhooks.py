from fastapi import APIRouter, HTTPException, Header, Depends
from pydantic import BaseModel
from typing import Optional, Dict, Any
import logging
import hmac
import hashlib
import json
from datetime import datetime

from config import get_settings
from database import Database
from blitz_client import BlitzClient

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks", tags=["webhooks"])
settings = get_settings()
db = Database(settings.DB_PATH)
blitz = BlitzClient(settings.BLITZ_API_URL, settings.BLITZ_ADMIN_USERNAME, settings.BLITZ_ADMIN_PASSWORD)

class WebhookEvent(BaseModel):
    event_type: str
    corporate_id: str
    event_data: Dict[str, Any]
    timestamp: datetime
    signature: Optional[str] = None

class UserDeactivatedEvent(BaseModel):
    corporate_id: str
    deactivation_reason: str
    deactivated_by: str
    effective_date: datetime

class UserRoleChangedEvent(BaseModel):
    corporate_id: str
    old_role: str
    new_role: str
    changed_by: str
    effective_date: datetime

def verify_webhook_signature(payload: bytes, signature: str, secret: str) -> bool:
    """Verify webhook signature using HMAC-SHA256"""
    expected_signature = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(signature, expected_signature)

@router.post("/hr-events")
async def handle_hr_webhook(
    event: WebhookEvent,
    x_hub_signature_256: Optional[str] = Header(None, alias="X-Hub-Signature-256")
):
    """
    Handle HR system webhooks for user lifecycle events
    
    Supported event types:
    - user_deactivated: User left the company
    - user_role_changed: User role changed (may affect VPN access)
    - user_suspended: User temporarily suspended
    """
    
    # Verify signature if provided
    if x_hub_signature_256 and settings.WEBHOOK_SECRET:
        payload = json.dumps(event.dict(exclude={'signature'}), default=str).encode()
        signature = x_hub_signature_256.replace('sha256=', '')
        
        if not verify_webhook_signature(payload, signature, settings.WEBHOOK_SECRET):
            logger.warning(f"Invalid webhook signature for event {event.event_type}")
            raise HTTPException(status_code=401, detail="Invalid signature")
    
    # Log webhook event
    await db.create_webhook_event(
        event_type=event.event_type,
        corporate_id=event.corporate_id,
        event_data=json.dumps(event.event_data, default=str)
    )
    
    logger.info(f"Received HR webhook: {event.event_type} for user {event.corporate_id}")
    
    # Process event based on type
    try:
        if event.event_type == "user_deactivated":
            await handle_user_deactivated(event.corporate_id, event.event_data)
        elif event.event_type == "user_role_changed":
            await handle_user_role_changed(event.corporate_id, event.event_data)
        elif event.event_type == "user_suspended":
            await handle_user_suspended(event.corporate_id, event.event_data)
        else:
            logger.warning(f"Unknown event type: {event.event_type}")
            
    except Exception as e:
        logger.error(f"Error processing webhook event {event.event_type}: {e}")
        raise HTTPException(status_code=500, detail="Error processing event")
    
    return {"status": "processed", "event_id": event.corporate_id}

async def handle_user_deactivated(corporate_id: str, event_data: Dict[str, Any]):
    """Handle user deactivation event"""
    
    # Get user from database
    user = await db.get_user(corporate_id)
    if not user:
        logger.warning(f"User {corporate_id} not found in database")
        return
    
    try:
        username = user['blitz_username']
        await blitz.update_user_status(username, False)
        logger.info(f"Deactivated Blitz user {username} for corporate_id {corporate_id}")
        
        # Update database
        await db.deactivate_user(corporate_id)
        
        # Log the action
        await db.log_auth_attempt(
            corporate_id=corporate_id,
            telegram_id=user.get('telegram_id'),
            action="user_deactivated",
            ip_address="system",
            user_agent="webhook",
            success=True,
            error_message=f"Deactivation reason: {event_data.get('deactivation_reason', 'unknown')}"
        )
        
        # Notify user via Telegram if linked
        if user.get('telegram_id'):
            # This would send Telegram notification
            logger.info(f"Would notify Telegram user {user['telegram_id']} about deactivation")
        
    except Exception as e:
        logger.error(f"Failed to deactivate user {corporate_id}: {e}")
        raise

async def handle_user_role_changed(corporate_id: str, event_data: Dict[str, Any]):
    """Handle user role change event"""
    
    user = await db.get_user(corporate_id)
    if not user:
        logger.warning(f"User {corporate_id} not found in database")
        return
    
    old_role = event_data.get('old_role')
    new_role = event_data.get('new_role')
    
    logger.info(f"User {corporate_id} role changed from {old_role} to {new_role}")
    
    # Check if role change affects VPN access
    # This would implement business logic based on roles
    # For example, some roles might not need VPN access
    
    if new_role in ["contractor", "intern", "visitor"]:
        # These roles might have limited or no VPN access
        logger.info(f"Role {new_role} may have limited VPN access")
        # Implement role-based access control logic here

async def handle_user_suspended(corporate_id: str, event_data: Dict[str, Any]):
    """Handle user suspension event"""
    
    user = await db.get_user(corporate_id)
    if not user:
        logger.warning(f"User {corporate_id} not found in database")
        return
    
    suspension_reason = event_data.get('suspension_reason', 'unknown')
    suspension_duration = event_data.get('duration_days', 0)
    
    logger.info(f"Suspending user {corporate_id} for {suspension_duration} days: {suspension_reason}")
    
    # Lock user for specified duration
    await db.lock_user(corporate_id, suspension_duration * 24 * 60)  # Convert days to minutes
    
    # Log the suspension
    await db.log_auth_attempt(
        corporate_id=corporate_id,
        telegram_id=user.get('telegram_id'),
        action="user_suspended",
        ip_address="system",
        user_agent="webhook",
        success=True,
        error_message=f"Suspension reason: {suspension_reason}, duration: {suspension_duration} days"
    )

@router.get("/events/pending")
async def get_pending_webhook_events(
    x_corporate_secret: str = Header(..., alias="X-Corporate-Secret")
):
    """Get pending webhook events for processing"""
    
    if x_corporate_secret != settings.CORPORATE_SECRET:
        raise HTTPException(status_code=403, detail="Invalid corporate secret")
    
    events = await db.get_pending_webhook_events()
    return {"events": events}

@router.post("/events/{event_id}/process")
async def mark_event_processed(
    event_id: int,
    x_corporate_secret: str = Header(..., alias="X-Corporate-Secret")
):
    """Mark webhook event as processed"""
    
    if x_corporate_secret != settings.CORPORATE_SECRET:
        raise HTTPException(status_code=403, detail="Invalid corporate secret")
    
    await db.mark_webhook_event_processed(event_id)
    return {"status": "processed"}

@router.get("/health")
async def webhook_health():
    """Health check for webhook system"""
    return {"status": "healthy", "timestamp": datetime.now()}
