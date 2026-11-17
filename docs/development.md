# 開発ガイド

## 1. 開発環境

| 項目 | バージョン |
| --- | --- |
| Xcode | 27.2 で動作確認 |
| 最低対応 OS | iOS 17.4 |
| Swift | 5（Swift 5 言語モード） |
| 依存パッケージ | firebase-ios-sdk 10.23（SPM、`FirebaseAnalyticsWithoutAdIdSupport`。広告ID（IDFA）を使わない版） |
| Bundle ID | `com.carrot.Cacarrot` |
| アプリのカテゴリ | ブック（`LSApplicationCategoryType`） |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の HTTPS のみ使用。アップロードのたびの暗号化の質問を省く） |
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

- アプリの単体テストは `CacarrotTests/`（XCTest）にあります。共有スキーム `Cacarrot` に含まれているので、Xcode の ⌘U か次のコマンドで実行できます。

```bash
xcodebuild test -project Cacarrot.xcodeproj -scheme Cacarrot -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

| ファイル | 内容 |
| --- | --- |
| `RecommendationEngineTests` | 好み度の計算、並べ替え、4枚に1枚の発見枠（乱数は `SeededGenerator` で固定） |
| `SwipeHistoryStoreTests` | 保存・更新・削除、判定だけの変更、取り消し用の履歴の順番、`likedPredicate` |
| `SaveFailureTests` | 保存に失敗したとき（`FlakyHistoryStore` で再現）に、カード・取り消し履歴・デッキが壊れず、エラーを表示すること |
| `SwipeDeckViewModelTests` | しきい値、判定と取り消し、再起動後の取り消し、スキップを戻す・リセット、絞り込み、おすすめ設定の保存、お気に入りの判定変更、利用イベント（偽物の `SpyAnalytics` で確認）、視差効果を減らす |

- テストはメモリ上の SwiftData と、テストごとの UserDefaults を使うので、アプリのデータには影響しません。

### UI テスト（CacarrotUITests）

| テスト | 内容 |
| --- | --- |
| `testLikeFromButtonThenUndo` | 使い方を閉じる → ボタンでいいね → お気に入りに出る → 取り消す |
| `testSwipeGesture` | カードを実際に左へスワイプしてスキップ |
| `testGenreFilter` | 「ギャグ」で絞り込むと1作品になる |
| `testJudgeFromDetailSheet` | カードをタップして詳細を開き、スーパーいいね |
| `testRestoreOneSkippedTitleFromMyPage` | スキップ → マイページの一覧から1作品だけデッキに戻す |

- アプリを起動引数 `-uiTesting` で起動します。このときは、メモリ上のデータ・専用の UserDefaults（`CacarrotUITesting`）・サンプル6作品・おすすめ順オフで動き、Firebase も初期化しません。端末に保存された履歴や設定には触れません。
- 画面の要素は `accessibilityIdentifier`（`deck.remaining`、`action.like`、`detail.superLike` など）で探します。文言を変えてもテストが壊れないように、新しい操作にも識別子を付けてください。
- 5件で約1分20秒かかります。単体テストだけを実行するときは `-only-testing:CacarrotTests` を付けます。
- `commit(_:action:)` は、アニメーションを待たずに判定を確定するため、テストから直接呼んでいます。
- データ変換スクリプトの単体テストは、次のコマンドで実行できます。

```bash
cd MangaInfoFetcher && python3 -m unittest discover -s tests -v
```
- 各 View には `#Preview` があります。プレビューでは `PreviewContainer` がメモリ上の SwiftData と `SampleMangaRepository` を使います。

## 4. 作品データの更新

### 楽天ブックスから（推奨）

1. 楽天ウェブサービスでアプリを登録し、次の値を `MangaInfoFetcher/.env` に書きます（Git の管理外）。
   - 「許可するIPアドレス」には、このMacのグローバルIPを登録します（`curl -s https://api.ipify.org` で確認できます）。

```
RAKUTEN_APP_ID=アプリID
RAKUTEN_ACCESS_KEY=pk_...
RAKUTEN_AFFILIATE_ID=（任意）
RAKUTEN_REFERER=https://github.com/carrot-99/Cacarrot
```

2. 接続を確認してから取得します（全ページで約2分）。標準ライブラリだけで動くので、venv は不要です。

```bash
cd MangaInfoFetcher && python3 fetch_rakuten.py --check
```

```bash
cd MangaInfoFetcher && python3 fetch_rakuten.py
```

3. `python3 build_app_data.py` で `manga.json` を作り直します（`rakuten_raw.json` があれば自動で楽天モードになります）。
4. 中身を確認します。特に、作品のまとめ方、あらすじ、表紙の解像度、楽天の区分を見てください。

### AniList から（旧方式）

1. 必要なら AniList から取得し直します。前回の続きのページから取得します（`MangaInfoFetcher/fetch_state.json` に保存。Git 管理外）。
   - 1 ページごとに 40 秒待つため、全件の取得には長い時間がかかります。
   - 標準ライブラリだけで動くので、venv は不要です。
   - `--start-page 1` で最初から、`--max-pages 10` で取得するページ数を制限できます。

```bash
cd MangaInfoFetcher && python3 query.py
```

2. アプリ用の JSON を作り直します。

```bash
cd MangaInfoFetcher && python3 build_app_data.py
```

- 出力先は `Cacarrot/Resources/manga.json` です。Xcode に登録済みなので、ビルドし直せば反映されます。
- 件数とスコアの下限は、`--limit` と `--min-score` で変えられます。
- `manga_info.csv` は大きいため、Git の管理外です。

## 5. プライバシーマニフェスト

- `Cacarrot/PrivacyInfo.xcprivacy` に、トラッキングの有無、収集するデータ、理由の申告が必要な API を書いています。
- 新しく次のものを使い始めたら、このファイルにも追加してください。
  - 理由の申告が必要な API（ファイルの日時、起動からの時間、ディスクの空き容量、キーボードの一覧など）
  - データを収集する SDK（その SDK 自身がマニフェストを持っていない場合）

## 6. 実装のルール

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
