"""build_app_data.py / fetch_rakuten.py の単体テスト

実行:
    cd MangaInfoFetcher && python3 -m unittest discover -s tests -v
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import build_app_data as b  # noqa: E402
import fetch_rakuten as f  # noqa: E402
import query as q  # noqa: E402


def item(title, author="芥見 下々", caption="あらすじです。", isbn="9784088815169",
         image="https://thumbnail.image.rakuten.co.jp/@0_mall/book/cabinet/5169/x.jpg?_ex=200x200",
         genre="001001001001", rank=None, **extra):
    data = {
        "title": title,
        "author": author,
        "itemCaption": caption,
        "isbn": isbn,
        "largeImageUrl": image,
        "booksGenreId": genre,
        "publisherName": "集英社",
        "itemUrl": "https://books.rakuten.co.jp/rb/1/",
        "affiliateUrl": "",
    }
    if rank is not None:
        data["_rank"] = rank
    data.update(extra)
    return data


class SeriesTitleTests(unittest.TestCase):
    def test_volume_patterns(self):
        cases = {
            "呪術廻戦 1": ("呪術廻戦", 1),
            "ONE PIECE 105": ("ONE PIECE", 105),
            "葬送のフリーレン（1）": ("葬送のフリーレン", 1),
            "葬送のフリーレン 第1巻": ("葬送のフリーレン", 1),
            "チェンソーマン 12 （ジャンプコミックス）": ("チェンソーマン", 12),
            "ＳＰＹ×ＦＡＭＩＬＹ　３": ("SPY×FAMILY", 3),
        }
        for title, expected in cases.items():
            with self.subTest(title=title):
                self.assertEqual(b.series_title(title), expected)

    def test_title_without_volume(self):
        self.assertEqual(b.series_title("よつばと!"), ("よつばと!", None))
        self.assertEqual(b.series_title("20世紀少年"), ("20世紀少年", None))


class CleanTests(unittest.TestCase):
    def test_author(self):
        self.assertEqual(b.clean_author("芥見 下々"), "芥見下々")
        self.assertEqual(b.clean_author("尾田 栄一郎/集英社"), "尾田栄一郎")
        self.assertEqual(b.clean_author("遠藤 達哉（著）"), "遠藤達哉")
        self.assertEqual(b.clean_author("Tatsuya Endo"), "Tatsuya Endo")

    def test_caption_removes_promotions(self):
        text = "【電子限定特典付き】少年は呪いと出会う。<br>※この商品は単行本です\n★描き下ろし付き"
        self.assertEqual(b.clean_caption(text), "少年は呪いと出会う。")

    def test_upscale_image(self):
        url = "https://thumbnail.image.rakuten.co.jp/a.jpg?_ex=200x200"
        self.assertTrue(b.upscale_image_url(url).endswith("_ex=600x600"))
        self.assertEqual(b.upscale_image_url("https://x/a.jpg"), "https://x/a.jpg")


class BuildFromRakutenTests(unittest.TestCase):
    anilist_rows = [
        {"Native Title": "呪術廻戦", "Genres": "Action, Supernatural"},
        {"Native Title": "えっちな作品", "Genres": "Comedy, Ecchi"},
    ]

    def test_groups_volumes_and_picks_first_volume(self):
        raw = [
            item("呪術廻戦 3", isbn="3", caption="3巻のあらすじ", rank=0),
            item("呪術廻戦 1", isbn="1", caption="1巻のあらすじ", rank=5),
            item("呪術廻戦 2", isbn="2", rank=1),
        ]
        result = b.build_from_rakuten(raw, self.anilist_rows, 10)
        self.assertEqual(len(result), 1)
        manga = result[0]
        self.assertEqual(manga["id"], 1)
        self.assertEqual(manga["title"], "呪術廻戦")
        self.assertEqual(manga["summary"], "1巻のあらすじ")
        self.assertEqual(manga["_rank"], 0)  # 一番売れている巻の順位で並べる

    def test_uses_next_volume_when_first_has_no_caption(self):
        raw = [item("呪術廻戦 1", isbn="1", caption=""), item("呪術廻戦 2", isbn="2", caption="2巻")]
        self.assertEqual(b.build_from_rakuten(raw, [], 10)[0]["summary"], "2巻")

    def test_genres_from_anilist_and_rakuten(self):
        manga = b.build_from_rakuten([item("呪術廻戦 1")], self.anilist_rows, 10)[0]
        self.assertEqual(manga["genres"], ["少年", "アクション", "超常"])

    def test_excludes_special_editions_ecchi_and_noimage(self):
        raw = [
            item("呪術廻戦 0 特装版", isbn="10"),
            item("えっちな作品 1", author="作者", isbn="11"),
            item("表紙なし 1", author="作者", isbn="12", image="https://x/noimage_01.gif"),
        ]
        self.assertEqual(b.build_from_rakuten(raw, self.anilist_rows, 10), [])

    def test_same_title_different_author_is_separate(self):
        raw = [item("ふたり 1", author="A", isbn="1"), item("ふたり 1", author="B", isbn="2")]
        self.assertEqual(len(b.build_from_rakuten(raw, [], 10)), 2)

    def test_prefers_affiliate_url_and_limit(self):
        raw = [item(f"作品{n} 1", isbn=str(n), affiliateUrl=f"https://hb.afl.rakuten.co.jp/{n}") for n in range(5)]
        result = b.build_from_rakuten(raw, [], 3)
        self.assertEqual(len(result), 3)
        self.assertEqual(result[0]["itemURL"], "https://hb.afl.rakuten.co.jp/0")

    def test_written_json_has_no_private_keys(self):
        import json
        import tempfile
        result = b.build_from_rakuten([item("呪術廻戦 1")], [], 10)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "out.json"
            b.write_output(result, path)
            saved = json.loads(path.read_text(encoding="utf-8"))
        self.assertNotIn("_rank", saved[0])
        self.assertEqual(set(saved[0]), {"id", "title", "author", "genres", "summary",
                                         "imageURL", "publisher", "itemURL"})


class AniListTests(unittest.TestCase):
    def test_is_japanese_title(self):
        self.assertTrue(b.is_japanese_title("ベルセルク"))
        self.assertTrue(b.is_japanese_title("寄生獣"))
        self.assertFalse(b.is_japanese_title("全职高手"))  # 簡体字
        self.assertFalse(b.is_japanese_title("Solo Leveling"))

    def test_clean_description(self):
        text = "Guts<br>is a <b>swordsman</b>. (Source: MU)<br><br><i>Note: extra</i>"
        self.assertEqual(b.clean_description(text), "Guts\nis a swordsman.")


class FetchRakutenTests(unittest.TestCase):
    def test_load_env(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / ".env"
            path.write_text('# comment\nRAKUTEN_APP_ID="abc"\nRAKUTEN_ACCESS_KEY=pk_x\n', encoding="utf-8")
            env = f.load_env(path)
        self.assertEqual(env["RAKUTEN_APP_ID"], "abc")
        self.assertEqual(env["RAKUTEN_ACCESS_KEY"], "pk_x")

    def test_build_params(self):
        env = {"RAKUTEN_APP_ID": "id", "RAKUTEN_ACCESS_KEY": "pk", "RAKUTEN_AFFILIATE_ID": "aff"}
        params = f.build_params(env, page=2, hits=30, genre_id="001001", sort="sales")
        self.assertEqual(params["page"], "2")
        self.assertEqual(params["booksGenreId"], "001001")
        self.assertEqual(params["affiliateId"], "aff")

    def test_explain_error(self):
        self.assertIn("IP", f.explain_error('HTTP 403: {"error":"CLIENT_IP_NOT_ALLOWED"}'))


class QueryResumeTests(unittest.TestCase):
    """query.py の再開ページの決め方"""

    def setUp(self):
        import tempfile
        self.tmp = tempfile.TemporaryDirectory()
        tmp = Path(self.tmp.name)
        self.saved = (q.CSV_FILE, q.STATE_FILE)
        q.CSV_FILE, q.STATE_FILE = tmp / "manga_info.csv", tmp / "fetch_state.json"

    def tearDown(self):
        q.CSV_FILE, q.STATE_FILE = self.saved
        self.tmp.cleanup()

    def test_starts_from_first_page_without_csv(self):
        self.assertEqual(q.load_next_page(), 1)

    def test_falls_back_to_legacy_page_when_csv_exists(self):
        q.CSV_FILE.write_text("ID\n1\n", encoding="utf-8")
        self.assertEqual(q.load_next_page(), q.LEGACY_START_PAGE)

    def test_state_file_wins(self):
        q.CSV_FILE.write_text("ID\n1\n", encoding="utf-8")
        q.save_next_page(2100)
        self.assertEqual(q.load_next_page(), 2100)


if __name__ == "__main__":
    unittest.main()
