"""AniList GraphQL API から漫画情報を取得し、manga_info.csv に追記する

使い方（標準ライブラリだけで動く。venv 不要）:
    cd MangaInfoFetcher
    python3 query.py                    # 前回の続きから
    python3 query.py --max-pages 10     # 10ページだけ取得
    python3 query.py --start-page 1     # 最初から
"""

import argparse
import csv
import json
import time
import urllib.error
import urllib.request
from pathlib import Path


def fetch_manga_info(page):
    query = (
        """
    {
      Page(page: %d, perPage: 50) {
        pageInfo {
          total
          currentPage
          lastPage
          hasNextPage
        }
        media(type: MANGA) {
          id
          title {
            romaji
            english
            native
          }
          coverImage {
            large
          }
          genres
          averageScore
          description(asHtml: false)
          startDate {
            year
            month
            day
          }
          staff {
            edges {
              node {
                name {
                  full
                }
              }
            }
          }
        }
      }
    }
    """
        % page
    )

    request = urllib.request.Request(
        "https://graphql.anilist.co",
        data=json.dumps({"query": query}).encode("utf-8"),
        # urllib 既定の User-Agent は Cloudflare に拒否される（Error 1010）ため、独自の名前を付ける
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "CacarrotDataFetcher/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        # エラー内容（レート制限など）も JSON で返ってくるので、呼び出し側で表示できるようにする
        try:
            return json.load(error)
        except ValueError:
            return {"errors": [{"status": error.code, "message": str(error)}]}
    except urllib.error.URLError as error:
        return {"errors": [{"message": str(error.reason)}]}


# CSVファイルに保存する関数
def save_to_csv(manga_info, csv_writer):
    for manga in manga_info:
        # スタッフの名前がNoneでないことを確認してリスト化
        staff_names = [
            edge["node"]["name"]["full"]
            for edge in manga.get("staff", {}).get("edges", [])
            if edge["node"]["name"]["full"] is not None
        ]

        # 発行開始日のフォーマット
        start_date = manga.get("startDate", {})
        year = start_date.get("year", 0) or 0
        month = start_date.get("month", 0) or 0
        day = start_date.get("day", 0) or 0
        formatted_date = f"{year}-{month:02d}-{day:02d}"

        # descriptionがNoneの場合は空の文字列を使う
        description = manga.get("description") or ""
        description = description.replace("\n", " ")

        manga_data = [
            manga.get("id", ""),
            manga["title"].get("romaji", ""),
            manga["title"].get("english", ""),
            manga["title"].get("native", ""),
            manga["coverImage"].get("large", ""),
            ", ".join(manga.get("genres", [])),
            manga.get("averageScore", ""),
            description,
            formatted_date,
            "; ".join(staff_names),
        ]
        csv_writer.writerow(manga_data)


# メインの処理
HERE = Path(__file__).resolve().parent
CSV_FILE = HERE / "manga_info.csv"  # 取得ファイル
STATE_FILE = HERE / "fetch_state.json"  # 次に取得するページを保存（Git 管理外）
LEGACY_START_PAGE = 1995  # 状態ファイル導入前に手で書いていた再開ページ
HEADER = [
    "ID",
    "Romaji Title",
    "English Title",
    "Native Title",
    "Cover Image",
    "Genres",
    "Average Score",
    "Description",
    "Start Date",
    "Staff Names",
]


def load_next_page() -> int:
    """再開ページ：状態ファイル → （CSV があれば）従来の値 → 1 の順に決める"""
    if STATE_FILE.exists():
        return int(json.loads(STATE_FILE.read_text(encoding="utf-8"))["next_page"])
    if CSV_FILE.exists() and CSV_FILE.stat().st_size > 0:
        return LEGACY_START_PAGE
    return 1


def save_next_page(page: int) -> None:
    STATE_FILE.write_text(json.dumps({"next_page": page}), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="AniList から漫画情報を取得して manga_info.csv に追記する")
    parser.add_argument("--start-page", type=int, help="このページから取得する（省略時は前回の続き）")
    parser.add_argument("--max-pages", type=int, help="今回取得する最大ページ数")
    parser.add_argument("--interval", type=float, default=40, help="ページごとの待ち時間（秒）")
    args = parser.parse_args()

    page = args.start_page or load_next_page()
    needs_header = not CSV_FILE.exists() or CSV_FILE.stat().st_size == 0
    fetched = 0
    print(f"{page} ページ目から取得します")

    with CSV_FILE.open("a", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        if needs_header:  # 新しいファイルのときだけヘッダーを書き込む
            writer.writerow(HEADER)

        while True:
            response_json = fetch_manga_info(page)

            # レスポンスの確認
            if response_json is None:
                print("Response is None, possibly due to an invalid request or server issue.")
                break

            if "errors" in response_json:
                print("Errors in the response:", response_json["errors"])
                break  # エラーが検出された場合は処理を中断

            if (
                "data" not in response_json
                or "Page" not in response_json["data"]
                or not response_json["data"]["Page"]["media"]
            ):
                print("Unexpected response structure or no media data found. Response:", response_json)
                break  # 'data'キーがない場合や想定外のレスポンス構造の場合は処理を中断

            save_to_csv(response_json["data"]["Page"]["media"], writer)
            file.flush()
            fetched += 1

            # 書き込みが終わったページの次を保存しておく（途中で止めても続きから再開できる）
            page_info = response_json["data"]["Page"]["pageInfo"]
            save_next_page(page + 1)
            if not page_info["hasNextPage"]:
                break
            if args.max_pages and fetched >= args.max_pages:
                break

            page += 1
            print(f"Completed page {page_info['currentPage']}. Moving to page {page}")

            # APIのレート制限に対応するために待機
            time.sleep(args.interval)

    print(f"Data collection complete.（{fetched} ページ取得。次回は {load_next_page()} ページ目から）")


if __name__ == "__main__":
    main()
