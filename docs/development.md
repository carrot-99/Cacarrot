# 開発ガイド

## 1. 開発環境

| 項目 | バージョン |
| --- | --- |
| Xcode | 27.2 で動作確認 |
| 最低対応 OS | iOS 17.4 |
| Swift | 5（Swift 5 言語モード） |
| 依存パッケージ | firebase-ios-sdk 10.23 以上（SPM、FirebaseCore と FirebaseAnalytics） |
| Bundle ID | `com.carrot.Cacarrot` |
| Python | 3（データ変換用。標準ライブラリだけで動く） |

## 2. セットアップ

```bash
open Cacarrot.xcodeproj
```

- `GoogleService-Info.plist` は Git の管理外です。Firebase コンソールからダウンロードし、`Cacarrot/` に置いてください。
  - このファイルがないと、起動時の `FirebaseApp.configure()` でアプリが落ちます。
- SPM のパッケージは、Xcode が初回に自動で解決します。

## 3. ビルド

```bash
xcodebuild -project Cacarrot.xcodeproj -scheme Cacarrot -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
```

- テストターゲットはまだありません（[issues.md](issues.md) を参照）。
- 各 View には `#Preview` があります。プレビューでは `PreviewContainer` がメモリ上の SwiftData と `SampleMangaRepository` を使います。

## 4. 作品データの更新

1. 必要なら AniList から取得し直します。`query.py` の `start_page` を確認してから実行してください。
   - 1 ページごとに 40 秒待つため、全件の取得には長い時間がかかります。
   - `requests` が必要なので、venv を使います。

```bash
source venv/bin/activate && cd MangaInfoFetcher && python query.py
```

2. アプリ用の JSON を作り直します。

```bash
cd MangaInfoFetcher && python3 build_app_data.py
```

- 出力先は `Cacarrot/Resources/manga.json` です。Xcode に登録済みなので、ビルドし直せば反映されます。
- 件数とスコアの下限は、`--limit` と `--min-score` で変えられます。
- `manga_info.csv` は大きいため、Git の管理外です。

## 5. 実装のルール

**依存と状態**
- 新しい依存は `CacarrotApp.init()` で組み立て、`.environment` で渡します。View の body の中で ViewModel を作らないでください。
- デッキの状態を変える処理は、`SwipeDeckViewModel` に集めます。
  - View から `SwipeHistoryStore` を直接呼ばないでください。
  - 読み取りだけなら `@Query` を使ってかまいません。

**データの取得元**
- 取得元を変えるときは、`MangaRepository` に準拠した型を新しく作り、`CacarrotApp` で差し替えます。

**見た目**
- 色とサイズは `Theme` に追加し、View に直接書かないでください。

**Xcode プロジェクト**
- フォルダは同期グループではなく、通常のグループです。ファイルを追加するときは、Xcode から追加してください。
  - Finder で置いただけでは、ビルドに含まれません。
