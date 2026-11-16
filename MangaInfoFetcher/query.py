import requests
import csv
import time


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

    url = "https://graphql.anilist.co"
    response = requests.post(url, json={"query": query})
    return response.json()


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
csv_file = "manga_info.csv"  # 取得ファイル
start_page = 1995  # 取得再開ページ

with open(csv_file, "a", newline="", encoding="utf-8") as file:
    writer = csv.writer(file)
    if start_page == 1:  # 最初から開始する場合のみヘッダーを書き込む
        writer.writerow(
            [
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
        )

    page = start_page
    while True:
        response_json = fetch_manga_info(page)

        # レスポンスの確認
        if response_json is None:
            print(
                "Response is None, possibly due to an invalid request or server issue."
            )
            break

        if "errors" in response_json:
            print("Errors in the response:", response_json["errors"])
            break  # エラーが検出された場合は処理を中断

        if (
            "data" not in response_json
            or "Page" not in response_json["data"]
            or not response_json["data"]["Page"]["media"]
        ):
            print(
                "Unexpected response structure or no media data found. Response:",
                response_json,
            )
            break  # 'data'キーがない場合や想定外のレスポンス構造の場合は処理を中断

        manga_info = response_json["data"]["Page"]["media"]
        save_to_csv(manga_info, writer)

        # ページ情報の確認
        page_info = response_json["data"]["Page"]["pageInfo"]
        if not page_info["hasNextPage"]:
            break

        page += 1
        print(f"Completed page {page_info['currentPage']}. Moving to page {page}")

        # APIのレート制限に対応するために待機
        time.sleep(40)  # 40秒の待機時間を設定

print("Data collection complete.")
