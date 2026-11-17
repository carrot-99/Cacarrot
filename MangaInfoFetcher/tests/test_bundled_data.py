"""アプリに同梱している Cacarrot/Resources/manga.json の形を確認する

アプリ側（Manga の Decodable）が読めない形になっていると、起動時にデッキが空になるため、
データを作り直したときの確認に使う。
"""

import json
import unittest
from pathlib import Path
from urllib.parse import urlparse

DATA = Path(__file__).resolve().parents[2] / "Cacarrot" / "Resources" / "manga.json"


class BundledDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with DATA.open(encoding="utf-8") as f:
            cls.items = json.load(f)

    def test_is_non_empty_list(self):
        self.assertIsInstance(self.items, list)
        self.assertGreater(len(self.items), 0)

    def test_required_fields(self):
        for item in self.items:
            with self.subTest(id=item.get("id")):
                self.assertIsInstance(item["id"], int)
                self.assertTrue(item["title"].strip())
                self.assertIsInstance(item["author"], str)
                self.assertIsInstance(item["summary"], str)
                self.assertIsInstance(item["genres"], list)
                self.assertTrue(all(isinstance(g, str) and g for g in item["genres"]))

    def test_ids_are_unique(self):
        ids = [item["id"] for item in self.items]
        self.assertEqual(len(ids), len(set(ids)))

    def test_urls_are_https(self):
        for item in self.items:
            for key in ("imageURL", "itemURL"):
                value = item.get(key)
                if value is None:
                    continue
                with self.subTest(id=item["id"], key=key):
                    self.assertEqual(urlparse(value).scheme, "https")


if __name__ == "__main__":
    unittest.main()
