"""楽天ブックス書籍検索API からコミックを取得し、rakuten_raw.json に保存する

事前準備:
    MangaInfoFetcher/.env に以下を書く（Git 管理外）
        RAKUTEN_APP_ID=...
        RAKUTEN_ACCESS_KEY=pk_...
        RAKUTEN_AFFILIATE_ID=...        # 任意
        RAKUTEN_REFERER=https://github.com/carrot-99/Cacarrot

使い方:
    cd MangaInfoFetcher
    python3 fetch_rakuten.py --check        # 1件だけ取得して接続確認
    python3 fetch_rakuten.py --pages 100    # 売れ筋順に最大 3000 件

標準ライブラリだけで動く（venv 不要）。
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ENV_PATH = HERE / ".env"
DEFAULT_OUTPUT = HERE / "rakuten_raw.json"

ENDPOINT = "https://openapi.rakuten.co.jp/services/api/BooksBook/Search/20170404"
COMIC_GENRE_ID = "001001"  # 漫画（コミック）
HITS_PER_PAGE = 30         # API の上限
MAX_PAGE = 100             # API の上限
REQUEST_INTERVAL = 1.2     # 1秒1リクエストの制限に余裕を持たせる


def load_env(path: Path = ENV_PATH) -> dict[str, str]:
    """KEY=VALUE 形式の .env を読む（python-dotenv 不要）。環境変数が優先"""
    values: dict[str, str] = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"').strip("'")
    for key in ("RAKUTEN_APP_ID", "RAKUTEN_ACCESS_KEY", "RAKUTEN_AFFILIATE_ID", "RAKUTEN_REFERER"):
        if os.environ.get(key):
            values[key] = os.environ[key]
    return values


def build_params(env: dict[str, str], page: int, hits: int, genre_id: str, sort: str) -> dict[str, str]:
    params = {
        "applicationId": env["RAKUTEN_APP_ID"],
        "accessKey": env["RAKUTEN_ACCESS_KEY"],
        "booksGenreId": genre_id,
        "sort": sort,
        "hits": str(hits),
        "page": str(page),
        "format": "json",
        "formatVersion": "2",
        "outOfStockFlag": "1",  # 品切れ・絶版も含める
    }
    if env.get("RAKUTEN_AFFILIATE_ID"):
        params["affiliateId"] = env["RAKUTEN_AFFILIATE_ID"]
    return params


def fetch_page(env: dict[str, str], page: int, hits: int, genre_id: str, sort: str) -> dict:
    url = ENDPOINT + "?" + urllib.parse.urlencode(build_params(env, page, hits, genre_id, sort))
    headers = {"User-Agent": "CacarrotDataFetcher/1.0"}
    if env.get("RAKUTEN_REFERER"):
        headers["Referer"] = env["RAKUTEN_REFERER"]
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {error.code}: {body}") from None


def explain_error(message: str) -> str:
    hints = {
        "CLIENT_IP_NOT_ALLOWED": "このMacのIPがアプリ設定に登録されていません（curl -s https://api.ipify.org で確認し、登録後5〜10分待つ）",
        "HTTP_REFERRER_MISSING": ".env の RAKUTEN_REFERER を設定してください",
        "HTTP_REFERRER_NOT_ALLOWED": "RAKUTEN_REFERER がアプリ設定の「許可するWebサイト」と一致していません",
        "wrong_parameter": "パラメータが不正です（アプリID・アクセスキーを確認）",
        "too_many_requests": "リクエストが多すぎます。時間をおいて再実行してください",
        "HTTP 404": "エンドポイントが変わった可能性があります（楽天のAPIテストフォームでURLを確認）",
        "HTTP 503": "楽天側のサーバが停止中です。時間をおいて再実行してください",
    }
    for key, hint in hints.items():
        if key in message:
            return f"{message}\n→ {hint}"
    return message


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pages", type=int, default=MAX_PAGE, help="取得するページ数（1ページ30件）")
    parser.add_argument("--genre", default=COMIC_GENRE_ID, help="booksGenreId（初期値: 001001 コミック）")
    parser.add_argument("--sort", default="sales", help="sales（売れ筋）/ reviewAverage など")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true", help="1件だけ取得して接続を確認する")
    args = parser.parse_args()

    env = load_env()
    missing = [k for k in ("RAKUTEN_APP_ID", "RAKUTEN_ACCESS_KEY") if not env.get(k)]
    if missing:
        print(f"{ENV_PATH} に {', '.join(missing)} がありません", file=sys.stderr)
        return 1

    if args.check:
        try:
            data = fetch_page(env, 1, 1, args.genre, args.sort)
        except (RuntimeError, urllib.error.URLError) as error:
            print("接続に失敗しました:\n" + explain_error(str(error)), file=sys.stderr)
            return 1
        items = data.get("Items", [])
        print(f"接続OK（該当 {data.get('count')} 件）")
        if items:
            item = items[0]
            print(json.dumps({k: item.get(k) for k in ("title", "author", "publisherName", "largeImageUrl", "itemUrl")},
                             ensure_ascii=False, indent=1))
        return 0

    items: list[dict] = []
    last_page = min(args.pages, MAX_PAGE)
    for page in range(1, last_page + 1):
        try:
            data = fetch_page(env, page, HITS_PER_PAGE, args.genre, args.sort)
        except (RuntimeError, urllib.error.URLError) as error:
            print(f"{page} ページ目で中断しました:\n" + explain_error(str(error)), file=sys.stderr)
            break
        page_items = data.get("Items", [])
        # 売れ筋順の順位を残しておく（作品ごとにまとめたあとの並び順に使う）
        for index, item in enumerate(page_items):
            item["_rank"] = (page - 1) * HITS_PER_PAGE + index
        items.extend(page_items)
        print(f"{page}/{data.get('pageCount', '?')} ページ（累計 {len(items)} 件）")
        if page >= int(data.get("pageCount") or 0):
            break
        time.sleep(REQUEST_INTERVAL)

    if not items:
        print("1件も取得できませんでした", file=sys.stderr)
        return 1
    args.output.write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(items)} 件を {args.output} に保存しました")
    return 0


if __name__ == "__main__":
    sys.exit(main())
