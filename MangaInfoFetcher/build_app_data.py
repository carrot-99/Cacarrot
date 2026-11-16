"""manga_info.csv からアプリ同梱用の manga.json を生成する

使い方:
    cd MangaInfoFetcher
    python3 build_app_data.py            # 上位500件
    python3 build_app_data.py --limit 1000 --min-score 70
"""

import argparse
import csv
import html
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_INPUT = HERE / "manga_info.csv"
DEFAULT_OUTPUT = HERE.parent / "Cacarrot" / "Resources" / "manga.json"

# App Store 審査を考慮して除外するジャンル
EXCLUDED_GENRES = {"Hentai", "Ecchi"}

GENRE_JA = {
    "Action": "アクション",
    "Adventure": "冒険",
    "Comedy": "コメディ",
    "Drama": "ドラマ",
    "Fantasy": "ファンタジー",
    "Horror": "ホラー",
    "Mahou Shoujo": "魔法少女",
    "Mecha": "ロボット",
    "Music": "音楽",
    "Mystery": "ミステリー",
    "Psychological": "心理",
    "Romance": "恋愛",
    "Sci-Fi": "SF",
    "Slice of Life": "日常",
    "Sports": "スポーツ",
    "Supernatural": "超常",
    "Thriller": "スリラー",
}

KANA = re.compile(r"[぀-ヿ]")
KANJI = re.compile(r"[一-鿿]")


def is_japanese_title(title: str) -> bool:
    """かなを含む、または漢字のみでも Shift_JIS で表せる（簡体字を除外）タイトルを日本作品とみなす"""
    if KANA.search(title):
        return True
    if not KANJI.search(title):
        return False
    try:
        title.encode("shift_jis")
        return True
    except UnicodeEncodeError:
        return False


def clean_description(text: str) -> str:
    """HTMLタグ・出典表記・注記を取り除く"""
    text = re.split(r"<i>\s*Notes?:", text, flags=re.I)[0]
    text = re.sub(r"<br\s*/?>", "\n", text, flags=re.I)
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text)
    text = re.sub(r"\(\s*Source:[^)]*\)", "", text, flags=re.I)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\s*\n\s*", "\n", text).strip()
    return re.sub(r"\n{2,}", "\n", text)


def build(input_path: Path, output_path: Path, limit: int, min_score: int) -> int:
    seen: set[int] = set()
    items = []
    with input_path.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            try:
                manga_id = int(row["ID"])
                score = int(row["Average Score"])
            except (TypeError, ValueError):
                continue
            if manga_id in seen or score < min_score:
                continue

            title = (row["Native Title"] or "").strip()
            cover = (row["Cover Image"] or "").strip()
            genres_en = [g.strip() for g in (row["Genres"] or "").split(",") if g.strip()]
            summary = clean_description(row["Description"] or "")
            if not (is_japanese_title(title) and cover and summary):
                continue
            if EXCLUDED_GENRES & set(genres_en):
                continue

            staff = [s.strip() for s in (row["Staff Names"] or "").split(";") if s.strip()]
            seen.add(manga_id)
            items.append({
                "id": manga_id,
                "title": title,
                "author": staff[0] if staff else "",
                "genres": [GENRE_JA.get(g, g) for g in genres_en],
                "summary": summary,
                "imageURL": cover.replace("/cover/medium/", "/cover/large/"),
                "score": score,
            })

    items.sort(key=lambda m: (-m["score"], m["id"]))
    items = items[:limit]
    for item in items:
        del item["score"]

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    return len(items)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--limit", type=int, default=500)
    parser.add_argument("--min-score", type=int, default=75)
    args = parser.parse_args()
    count = build(args.input, args.output, args.limit, args.min_score)
    print(f"{count} 件を {args.output} に書き出しました")
