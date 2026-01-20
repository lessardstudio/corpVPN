import aiosqlite
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, Dict, Any

class Database:
    def __init__(self, db_path: str):
        self.db_path = db_path

    async def init_db(self):
        # Ensure directory exists
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
        
        async with aiosqlite.connect(self.db_path) as db:
            # Users table - updated for Hysteria2
            await db.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    corporate_id TEXT PRIMARY KEY,
                    blitz_username TEXT,
                    hy2_auth_key TEXT,
                    subscription_url TEXT,
                    hy2_url TEXT,
                    telegram_id TEXT UNIQUE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    is_active BOOLEAN DEFAULT 1,
                    last_access TIMESTAMP,
                    auth_attempts INTEGER DEFAULT 0,
                    locked_until TIMESTAMP,
                    total_upload BIGINT DEFAULT 0,
                    total_download BIGINT DEFAULT 0
                )
            """)
            
            # Authentication logs table
            await db.execute("""
                CREATE TABLE IF NOT EXISTS auth_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    corporate_id TEXT,
                    telegram_id TEXT,
                    action TEXT,
                    ip_address TEXT,
                    user_agent TEXT,
                    success BOOLEAN,
                    error_message TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (corporate_id) REFERENCES users(corporate_id)
                )
            """)
            
            # Webhook events table
            await db.execute("""
                CREATE TABLE IF NOT EXISTS webhook_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    event_type TEXT,
                    corporate_id TEXT,
                    event_data TEXT,
                    processed BOOLEAN DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    processed_at TIMESTAMP
                )
            """)
            
            # Traffic statistics table
            await db.execute("""
                CREATE TABLE IF NOT EXISTS traffic_stats (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    corporate_id TEXT,
                    username TEXT,
                    upload_bytes BIGINT,
                    download_bytes BIGINT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (corporate_id) REFERENCES users(corporate_id)
                )
            """)

            await db.execute("""
                CREATE TABLE IF NOT EXISTS monitor_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    component TEXT,
                    level TEXT,
                    message TEXT,
                    details TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            await db.execute("""
                CREATE TABLE IF NOT EXISTS id_registry (
                    id TEXT PRIMARY KEY,
                    owner TEXT,
                    status TEXT CHECK(status IN ('issued','active','revoked','archived')) DEFAULT 'issued',
                    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP
                )
            """)

            await db.execute("""
                CREATE TABLE IF NOT EXISTS id_audit (
                    audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    id TEXT,
                    action TEXT,
                    actor TEXT,
                    details TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(id) REFERENCES id_registry(id)
                )
            """)
            
            await db.commit()

    async def add_user(self, corporate_id: str, blitz_username: str, subscription_url: str, 
                      hy2_url: str, hy2_auth_key: str, telegram_id: Optional[str] = None):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                INSERT OR REPLACE INTO users (corporate_id, blitz_username, hy2_auth_key, 
                subscription_url, hy2_url, telegram_id, created_at, is_active)
                VALUES (?, ?, ?, ?, ?, ?, ?, 1)
            """, (corporate_id, blitz_username, hy2_auth_key, subscription_url, hy2_url, 
                  telegram_id, datetime.now()))
            await db.commit()

    async def get_user(self, corporate_id: str) -> Optional[Dict[str, Any]]:
        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            async with db.execute("SELECT * FROM users WHERE corporate_id = ?", (corporate_id,)) as cursor:
                row = await cursor.fetchone()
                return dict(row) if row else None
                
    async def get_user_by_telegram_id(self, telegram_id: str) -> Optional[Dict[str, Any]]:
        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            async with db.execute("SELECT * FROM users WHERE telegram_id = ?", (telegram_id,)) as cursor:
                row = await cursor.fetchone()
                return dict(row) if row else None

    async def link_telegram_to_corporate(self, telegram_id: str, corporate_id: str) -> bool:
        async with aiosqlite.connect(self.db_path) as db:
            # Check if telegram_id is already linked to another corporate_id
            async with db.execute("SELECT corporate_id FROM users WHERE telegram_id = ? AND corporate_id != ?", (telegram_id, corporate_id)) as cursor:
                existing = await cursor.fetchone()
                if existing:
                    return False  # Telegram ID already linked to another corporate ID
            
            # Link telegram_id to corporate_id
            await db.execute("UPDATE users SET telegram_id = ? WHERE corporate_id = ?", (telegram_id, corporate_id))
            await db.commit()
            return True

    async def deactivate_user(self, corporate_id: str):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("UPDATE users SET is_active = 0 WHERE corporate_id = ?", (corporate_id,))
            await db.commit()

    async def update_traffic_stats(self, corporate_id: str, upload_bytes: int, download_bytes: int):
        async with aiosqlite.connect(self.db_path) as db:
            user = await self.get_user(corporate_id)
            if user:
                new_upload = user.get('total_upload', 0) + upload_bytes
                new_download = user.get('total_download', 0) + download_bytes
                
                await db.execute("""
                    UPDATE users 
                    SET total_upload = ?, total_download = ?, last_access = ?
                    WHERE corporate_id = ?
                """, (new_upload, new_download, datetime.now(), corporate_id))
                
                # Insert traffic record
                await db.execute("""
                    INSERT INTO traffic_stats (corporate_id, username, upload_bytes, download_bytes)
                    VALUES (?, ?, ?, ?)
                """, (corporate_id, user['blitz_username'], upload_bytes, download_bytes))
                
                await db.commit()

    async def log_auth_attempt(self, corporate_id: str, telegram_id: str, action: str, 
                             ip_address: str, user_agent: str, success: bool, 
                             error_message: Optional[str] = None):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                INSERT INTO auth_logs (corporate_id, telegram_id, action, ip_address, user_agent, success, error_message)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (corporate_id, telegram_id, action, ip_address, user_agent, success, error_message))
            await db.commit()

    async def log_monitor_event(self, component: str, level: str, message: str, details: str = ""):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                """
                INSERT INTO monitor_events (component, level, message, details)
                VALUES (?, ?, ?, ?)
                """,
                (component, level, message, details),
            )
            await db.commit()

    async def get_user_auth_logs(self, corporate_id: str, limit: int = 10) -> list:
        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            async with db.execute("""
                SELECT * FROM auth_logs 
                WHERE corporate_id = ? 
                ORDER BY created_at DESC 
                LIMIT ?
            """, (corporate_id, limit)) as cursor:
                rows = await cursor.fetchall()
                return [dict(row) for row in rows]

    async def get_user_traffic_stats(self, corporate_id: str, days: int = 30) -> list:
        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            async with db.execute("""
                SELECT DATE(timestamp) as date, 
                       SUM(upload_bytes) as total_upload,
                       SUM(download_bytes) as total_download,
                       COUNT(*) as connection_count
                FROM traffic_stats 
                WHERE corporate_id = ? AND timestamp >= datetime('now', '-' || ? || ' days')
                GROUP BY DATE(timestamp)
                ORDER BY date DESC
            """, (corporate_id, days)) as cursor:
                rows = await cursor.fetchall()
                return [dict(row) for row in rows]

    async def create_webhook_event(self, event_type: str, corporate_id: str, event_data: str):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                INSERT INTO webhook_events (event_type, corporate_id, event_data)
                VALUES (?, ?, ?)
            """, (event_type, corporate_id, event_data))
            await db.commit()

    async def get_pending_webhook_events(self) -> list:
        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            async with db.execute("""
                SELECT * FROM webhook_events 
                WHERE processed = 0 
                ORDER BY created_at ASC
            """) as cursor:
                rows = await cursor.fetchall()
                return [dict(row) for row in rows]

    async def mark_webhook_event_processed(self, event_id: int):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                UPDATE webhook_events 
                SET processed = 1, processed_at = ? 
                WHERE id = ?
            """, (datetime.now(), event_id))
            await db.commit()

    async def increment_auth_attempts(self, corporate_id: str):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                UPDATE users 
                SET auth_attempts = auth_attempts + 1 
                WHERE corporate_id = ?
            """, (corporate_id,))
            await db.commit()

    async def lock_user(self, corporate_id: str, duration_minutes: int = 30):
        async with aiosqlite.connect(self.db_path) as db:
            locked_until = datetime.now() + timedelta(minutes=duration_minutes)
            await db.execute("""
                UPDATE users 
                SET locked_until = ? 
                WHERE corporate_id = ?
            """, (locked_until, corporate_id))
            await db.commit()

    async def is_user_locked(self, corporate_id: str) -> bool:
        async with aiosqlite.connect(self.db_path) as db:
            async with db.execute("SELECT locked_until FROM users WHERE corporate_id = ?", (corporate_id,)) as cursor:
                row = await cursor.fetchone()
                if row and row[0]:
                    locked_until = datetime.fromisoformat(row[0])
                    return datetime.now() < locked_until
                return False

    async def reset_auth_attempts(self, corporate_id: str):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                UPDATE users 
                SET auth_attempts = 0, locked_until = NULL 
                WHERE corporate_id = ?
            """, (corporate_id,))
            await db.commit()

    async def get_id(self, id_value: str) -> Optional[Dict[str, Any]]:
        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            async with db.execute("SELECT * FROM id_registry WHERE id = ?", (id_value,)) as cursor:
                row = await cursor.fetchone()
                return dict(row) if row else None

    async def create_id(self, id_value: str, owner: str):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                INSERT INTO id_registry (id, owner, status, issued_at)
                VALUES (?, ?, 'issued', ?)
            """, (id_value, owner, datetime.now()))
            await db.commit()

    async def set_id_status(self, id_value: str, status: str):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                UPDATE id_registry SET status = ?, updated_at = ? WHERE id = ?
            """, (status, datetime.now(), id_value))
            await db.commit()

    async def search_ids(self, query: str, limit: int = 20) -> list:
        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            like = f"%{query}%"
            async with db.execute("""
                SELECT * FROM id_registry
                WHERE id LIKE ? OR owner LIKE ? OR status LIKE ?
                ORDER BY issued_at DESC
                LIMIT ?
            """, (like, like, like, limit)) as cursor:
                rows = await cursor.fetchall()
                return [dict(row) for row in rows]

    async def audit_id_action(self, id_value: str, action: str, actor: str, details: str = ""):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                INSERT INTO id_audit (id, action, actor, details)
                VALUES (?, ?, ?, ?)
            """, (id_value, action, actor, details))
            await db.commit()
