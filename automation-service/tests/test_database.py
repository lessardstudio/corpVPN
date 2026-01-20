import os
import tempfile
import unittest

from database import Database


class TestDatabase(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.db_path = os.path.join(self.tmpdir.name, "users.db")
        self.db = Database(self.db_path)
        await self.db.init_db()

    async def asyncTearDown(self):
        self.tmpdir.cleanup()

    async def test_id_registry_roundtrip(self):
        await self.db.create_id("AB123456", "tester")
        rec = await self.db.get_id("AB123456")
        self.assertIsNotNone(rec)
        self.assertEqual(rec["id"], "AB123456")
        self.assertEqual(rec["owner"], "tester")

    async def test_id_status_update(self):
        await self.db.create_id("AB123456", "tester")
        await self.db.set_id_status("AB123456", "revoked")
        rec = await self.db.get_id("AB123456")
        self.assertEqual(rec["status"], "revoked")

