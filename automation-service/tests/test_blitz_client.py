import unittest

from blitz_client import BlitzClient


class TestBlitzClient(unittest.TestCase):
    def test_public_base_url_strips_api(self):
        c = BlitzClient("http://blitz:8000/api", "u", "p")
        self.assertEqual(c._public_base_url(), "http://blitz:8000")

    def test_public_base_url_keeps_non_api(self):
        c = BlitzClient("http://blitz:8000", "u", "p")
        self.assertEqual(c._public_base_url(), "http://blitz:8000")

