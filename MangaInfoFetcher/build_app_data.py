"""アプリ同梱用の manga.json を生成する

データ源:
    rakuten : fetch_rakuten.py で取得した rakuten_raw.json（日本語のあらすじ・表紙・商品リンク）
              ジャンル（アクション・恋愛など）は manga_info.csv（AniList）とタイトルで突き合わせて補う
    anilist : manga_info.csv のみ（英語のあらすじ。旧方式）

使い方:
    cd MangaInfoFetcher
    python3 build_app_data.py                      # rakuten_raw.json があれば rakuten、なければ anilist
    python3 build_app_data.py --source rakuten --limit 500
    python3 build_app_data.py --source anilist --limit 1000 --min-score 70
"""

import argparse
import csv
import html
import json
import re
import unicodedata
from pathlib import Path
from typing import Optional

HERE = Path(__file__).resolve().parent
DEFAULT_CSV = HERE / "manga_info.csv"
DEFAULT_RAKUTEN = HERE / "rakuten_raw.json"
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

# 楽天ブックスのコミック配下ジャンル（booksGenreId の先頭9桁）。実データで要確認
RAKUTEN_GENRE_JA = {
    "001001001": "少年",
    "001001002": "少女",
    "001001003": "青年",
    "001001004": "女性",
}

# 作品の1巻として扱わない商品（特装版・画集・ガイドブック・セットなど）
EXCLUDED_TITLE_WORDS = re.compile(
    r"特装版|限定版|同梱版|特別版|豪華版|愛蔵版|新装版|完全版|画集|イラスト集|ファンブック|公式ガイド|"
    r"ガイドブック|キャラクターブック|設定資料|ノベライズ|小説|セット|全巻|BOX|カレンダー|ポスター|"
    r"アンソロジー|総集編|フルカラー|カラー版|英語版|翻訳版|学習まんが|学習漫画",
    re.I,
)

# 末尾の巻数表記「 1」「（105）」「 第1巻」「 1巻」
VOLUME_PATTERN = re.compile(r"\s*(?:[(]\s*)?(?:第\s*)?(\d{1,3})\s*(?:巻)?\s*(?:[)])?\s*$")
# 末尾のレーベル表記「（ジャンプコミックス）」など（NFKC 後なので括弧は半角）
LABEL_SUFFIX = re.compile(r"\s*\([^()]*(?:コミックス|comics|コミック|文庫|ブックス|books)[^()]*\)\s*$", re.I)

KANA = re.compile(r"[぀-ヿ]")
KANJI = re.compile(r"[一-鿿]")


# MARK: - 共通

def normalize_key(text: str) -> str:
    """タイトル突き合わせ用のキー（全角半角・大文字小文字・記号・空白の違いを無視）"""
    text = unicodedata.normalize("NFKC", text).lower()
    return re.sub(r"[\s\W_]+", "", text)


def load_anilist_rows(csv_path: Path) -> list:
    """manga_info.csv を重複IDを除いて読む"""
    if not csv_path.exists():
        return []
    seen = set()
    rows = []
    with csv_path.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            try:
                manga_id = int(row["ID"])
            except (TypeError, ValueError):
                continue
            if manga_id in seen:
                continue
            seen.add(manga_id)
            rows.append(row)
    return rows


def split_genres(row: dict) -> list:
    return [g.strip() for g in (row.get("Genres") or "").split(",") if g.strip()]


# MARK: - AniList（旧方式）

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


def build_from_anilist(rows: list, limit: int, min_score: int) -> list:
    items = []
    for row in rows:
        try:
            score = int(row["Average Score"])
        except (TypeError, ValueError):
            continue
        if score < min_score:
            continue
        title = (row["Native Title"] or "").strip()
        cover = (row["Cover Image"] or "").strip()
        genres_en = split_genres(row)
        summary = clean_description(row["Description"] or "")
        if not (is_japanese_title(title) and cover and summary):
            continue
        if EXCLUDED_GENRES & set(genres_en):
            continue
        staff = [s.strip() for s in (row["Staff Names"] or "").split(";") if s.strip()]
        items.append({
            "id": int(row["ID"]),
            "title": title,
            "author": staff[0] if staff else "",
            "genres": [GENRE_JA.get(g, g) for g in genres_en],
            "summary": summary,
            "imageURL": cover.replace("/cover/medium/", "/cover/large/"),
            "_score": score,
        })
    items.sort(key=lambda m: (-m["_score"], m["id"]))
    return items[:limit]


# MARK: - 楽天ブックス

def series_title(title: str) -> tuple:
    """商品タイトルから作品名と巻数を取り出す。例: 「呪術廻戦 1（ジャンプコミックス）」→ ("呪術廻戦", 1)"""
    text = unicodedata.normalize("NFKC", title).strip()
    text = LABEL_SUFFIX.sub("", text)
    volume = None
    match = VOLUME_PATTERN.search(text)
    if match:
        candidate = text[: match.start()].strip()
        if candidate:  # タイトルが数字だけの場合は巻数とみなさない
            volume = int(match.group(1))
            text = candidate
    return text.strip(" ・-:"), volume


def clean_author(author: str) -> str:
    """「尾田 栄一郎/集英社」のような表記から1人目の名前を取り出し、日本語名の空白を詰める"""
    first = re.split(r"[/／,、]", author or "")[0].strip()
    first = re.sub(r"[(（][^)）]*[)）]", "", first).strip()  # 「（著）」など
    if KANA.search(first) or KANJI.search(first):
        first = re.sub(r"\s+", "", first)
    return first


def clean_caption(text: str) -> str:
    """商品説明から販売用の文言を取り除く"""
    text = html.unescape(text or "")
    text = re.sub(r"<br\s*/?>", "\n", text, flags=re.I)
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"【[^】]*(?:特典|限定|封入|予約|付録|電子|配信|発売|重版|注意)[^】]*】", "", text)
    lines = [line.strip() for line in text.splitlines()]
    lines = [line for line in lines if line and not line.startswith(("※", "★", "☆", "■"))]
    text = "\n".join(lines)
    text = re.sub(r"[ \t　]+", " ", text).strip()
    return re.sub(r"\n{2,}", "\n", text)


def upscale_image_url(url: str, size: int = 600) -> str:
    """楽天の書影URL（?_ex=200x200）を大きいサイズにする。対応サイズは実データで要確認"""
    if url and "_ex=" in url:
        return re.sub(r"_ex=\d+x\d+", f"_ex={size}x{size}", url)
    return url


def rakuten_demographic(item: dict) -> Optional[str]:
    for genre_id in re.split(r"[/,]", item.get("booksGenreId") or ""):
        if genre_id[:9] in RAKUTEN_GENRE_JA:
            return RAKUTEN_GENRE_JA[genre_id[:9]]
    return None


def anilist_genre_index(rows: list) -> dict:
    """原題（日本語）→ AniList ジャンル の対応表。同名がある場合は先に出た方"""
    index = {}
    for row in rows:
        key = normalize_key(row.get("Native Title") or "")
        if key and key not in index:
            index[key] = split_genres(row)
    return index


def _priority(candidate: dict) -> tuple:
    """代表にする商品の優先度（小さいほど優先）：あらすじがある → 巻数が若い"""
    has_caption = bool(clean_caption(candidate["item"].get("itemCaption") or ""))
    return (not has_caption, candidate["volume"])


def build_from_rakuten(raw_items: list, anilist_rows: list, limit: int) -> list:
    genre_index = anilist_genre_index(anilist_rows)
    groups = {}

    for rank, item in enumerate(raw_items):
        title = item.get("title") or ""
        if not title or EXCLUDED_TITLE_WORDS.search(title):
            continue
        image = item.get("largeImageUrl") or ""
        if not image or "noimage" in image:
            continue
        name, volume = series_title(title)
        author = clean_author(item.get("author") or "")
        key = normalize_key(name) + "|" + normalize_key(author)
        candidate = {
            "item": item,
            "name": name,
            "author": author,
            "volume": volume if volume is not None else 1,
            "rank": item.get("_rank", rank),
        }
        current = groups.get(key)
        if current is None:
            candidate["best_rank"] = candidate["rank"]
            groups[key] = candidate
            continue
        best_rank = min(current["best_rank"], candidate["rank"])
        if _priority(candidate) < _priority(current):
            groups[key] = candidate
        groups[key]["best_rank"] = best_rank

    items = []
    for group in groups.values():
        item = group["item"]
        summary = clean_caption(item.get("itemCaption") or "")
        if not summary:
            continue
        genres_en = genre_index.get(normalize_key(group["name"]), [])
        if EXCLUDED_GENRES & set(genres_en):
            continue
        genres = [GENRE_JA.get(g, g) for g in genres_en]
        demographic = rakuten_demographic(item)
        if demographic:
            genres.insert(0, demographic)
        isbn = re.sub(r"\D", "", item.get("isbn") or "")
        items.append({
            # ISBN（13桁）は Int に収まる。ない場合は順位から仮IDを振る
            "id": int(isbn) if isbn else 9_000_000_000_000 + group["best_rank"],
            "title": group["name"],
            "author": group["author"],
            "genres": genres,
            "summary": summary,
            "imageURL": upscale_image_url(item.get("largeImageUrl") or ""),
            "publisher": item.get("publisherName") or None,
            "itemURL": item.get("affiliateUrl") or item.get("itemUrl") or None,
            "_rank": group["best_rank"],
        })
    items.sort(key=lambda m: m["_rank"])
    return items[:limit]


# MARK: - 出力

def write_output(items: list, output_path: Path) -> None:
    cleaned = [{k: v for k, v in item.items() if not k.startswith("_") and v is not None} for item in items]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(cleaned, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", choices=["auto", "rakuten", "anilist"], default="auto")
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--rakuten", type=Path, default=DEFAULT_RAKUTEN)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--limit", type=int, default=500)
    parser.add_argument("--min-score", type=int, default=75, help="anilist のみ")
    args = parser.parse_args()

    source = args.source
    if source == "auto":
        source = "rakuten" if args.rakuten.exists() else "anilist"

    rows = load_anilist_rows(args.csv)
    if source == "rakuten":
        raw = json.loads(args.rakuten.read_text(encoding="utf-8"))
        result = build_from_rakuten(raw, rows, args.limit)
    else:
        result = build_from_anilist(rows, args.limit, args.min_score)

    write_output(result, args.output)
    print(f"[{source}] {len(result)} 件を {args.output} に書き出しました")
