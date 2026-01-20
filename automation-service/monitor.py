import asyncio
import logging
import httpx

from database import Database
from config import get_settings
from telegram_2fa import Telegram2FA

logger = logging.getLogger(__name__)
settings = get_settings()

class HealthMonitor:
    def __init__(self, db: Database, notifier: Telegram2FA):
        self.db = db
        self.notifier = notifier
        self._stop = False
        self._blitz_fail_count = 0

    async def start(self):
        asyncio.create_task(self._monitor_blitz())
        asyncio.create_task(self._monitor_automation())

    async def _monitor_blitz(self):
        base = settings.BLITZ_API_URL.rstrip("/")
        base = base[:-4] if base.endswith("/api") else base
        async with httpx.AsyncClient(timeout=5.0) as client:
            while not self._stop:
                try:
                    resp = await client.get(f"{base}/")
                    if resp.status_code == 200:
                        if self._blitz_fail_count:
                            self._blitz_fail_count = 0
                            await self.db.log_monitor_event("blitz", "INFO", "Recovered", "status 200")
                    else:
                        self._blitz_fail_count += 1
                        await self.db.log_monitor_event("blitz", "WARN", f"Status {resp.status_code}")
                except Exception as e:
                    self._blitz_fail_count += 1
                    await self.db.log_monitor_event("blitz", "ERROR", "Unreachable", str(e))

                # Notify admins on sustained failure
                if self._blitz_fail_count >= 3:
                    try:
                        await self.notifier.notify_admins("⚠️ Blitz недоступен. Проверьте контейнер и порты.")
                        # reset counter after notify to avoid spam
                        self._blitz_fail_count = 0
                    except Exception as ne:
                        logger.error(f"Notify failed: {ne}")

                await asyncio.sleep(30)

    async def _monitor_automation(self):
        # Placeholder for self health metrics; logs alive signal periodically
        while not self._stop:
            try:
                await self.db.log_monitor_event("automation", "INFO", "alive")
            except Exception as e:
                logger.error(f"monitor automation log error: {e}")
            await asyncio.sleep(300)
