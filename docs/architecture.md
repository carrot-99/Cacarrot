# アーキテクチャ設計書

## 1. 全体像

Cacarrot は、漫画のカードを左右上にスワイプして好みの作品を見つけるアプリです。構成は SwiftUI と MVVM です。

- **View**：表示と入力だけを担当します。
- **ViewModel**：デッキの状態とスワイプのロジックを持ちます。
- **Service**：データの取得と保存を担当します。

```mermaid
flowchart TD
    subgraph View
        APP[CacarrotApp<br/>依存の組み立て]
        CV[ContentView<br/>TabView]
        MV[MainView<br/>さがす]
        LV[LibraryView<br/>お気に入り]
        PV[ProfileView<br/>マイページ]
        CS[CardStackView / SwipeCardView]
        AB[ActionBarView]
        DV[MangaDetailView]
    end
    subgraph ViewModel
        VM[SwipeDeckViewModel<br/>デッキ・ドラッグ・判定・取り消し]
    end
    subgraph Service
        REPO[MangaRepository<br/>BundledMangaRepository]
        STORE[SwipeHistoryStore<br/>SwiftData]
    end

    APP --> CV
    CV --> MV & LV & PV
    MV --> CS & AB & DV
    CS --> VM
    AB --> VM
    LV -- forget --> VM
    PV -- restoreSkipped / resetAll --> VM
    LV -. "@Query" .-> DB
    PV -. "@Query" .-> DB
    VM --> REPO
    VM --> STORE
    REPO --> JSON[(Resources/manga.json)]
    STORE --> DB[(SwiftData<br/>SwipeRecord)]
```

### 依存の組み立て

依存は [CacarrotApp.swift](../Cacarrot/CacarrotApp.swift) でまとめて組み立てます。

1. `ModelContainer(for: SwipeRecord.self)` を作ります。開けなかった場合は、メモリ上のストアで起動します。
2. `SwipeDeckViewModel(repository: BundledMangaRepository(), store: SwipeHistoryStore(context: container.mainContext))` を `@State` で 1 つだけ持ちます。
3. その ViewModel を `.environment(deck)` で全画面に渡し、`.modelContainer(container)` で SwiftData を渡します。
4. `AppDelegate` で `FirebaseApp.configure()` を呼びます。

### 読み書きの分担

- **書き込み**：デッキ操作による書き込みは、すべて `SwipeDeckViewModel` から `SwipeHistoryStore` を通して行います。
- **読み取り**：お気に入り一覧と統計は、View が `@Query` で SwiftData を直接読みます。

## 2. レイヤーごとの責務

### Models（`Cacarrot/Models`）

| 型 | 役割 |
| --- | --- |
| `Manga` | カード 1 枚分の作品データ（id・タイトル・作者・ジャンル・あらすじ・`imageName?`・`imageURL?`）。値型でイミュータブル、`Codable` |
| `SwipeAction` | ユーザーの判定。`like` / `superLike` / `nope` の 3 つ。スタンプの文字・表示名・SF Symbols・色・画面外へ飛ぶ方向（`exitOffset(in:)`）を持つ |
| `SwipeRecord` | 判定の履歴。SwiftData の `@Model`。`mangaID` はユニーク。一覧表示用に作品情報のコピーを持ち、`manga` で `Manga` に戻せる |

### Services（`Cacarrot/Services`）

| 型 | 役割 |
| --- | --- |
| `MangaRepository` | 作品データの取得元を表すプロトコル（`fetchAll() async throws -> [Manga]`）。API や Firestore に差し替えられるようにしている |
| `BundledMangaRepository` | アプリに同梱した `manga.json` をバックグラウンドで読み込み、デコードしてシャッフルする |
| `SampleMangaRepository` | プレビュー用のサンプル 6 件。表紙はローカル画像 |
| `SwipeHistoryStore` | `SwipeRecord` の追加・更新・削除。ViewModel から SwiftData の細かい処理を隠す |

### ViewModels（`Cacarrot/ViewModels`）

`SwipeDeckViewModel`（`@Observable`、`@MainActor`）がアプリの中心です。

| 区分 | メンバー | 内容 |
| --- | --- | --- |
| 状態 | `cards` | 未判定のカード。先頭が一番上 |
| | `dragOffset` | 一番上のカードのドラッグ量 |
| | `cardSize` | カードの表示サイズ。ボタン操作で飛ばすときの距離に使う |
| | `loadState` | `idle` / `loading` / `loaded` / `failed(String)` |
| | `exitingAction` | 画面外へ飛ばしている最中の判定。`nil` 以外のあいだは操作を受け付けない |
| 読み込み | `loadIfNeeded()` / `reload()` | 全作品を取得し、判定済みの ID を除いてデッキを作る |
| ドラッグ | `dragChanged(_:)` / `dragEnded(translation:predicted:)` | しきい値の判定と触覚フィードバック |
| 判定 | `swipe(_:)` | カードを画面外へ飛ばし、アニメーションが終わったら `commit` で保存してデッキから外す |
| 取り消し | `undo()` | 直前の判定を取り消してカードを一番上に戻す。履歴はメモリ上だけで持つ |
| 管理 | `restoreSkipped()` / `resetAll()` / `forget(mangaID:)` | スキップを戻す、すべて消す、お気に入りから外してデッキの最後に戻す |
| 表示 | `stampOpacity(for:)` | GOOD / NOPE / SUPER スタンプの濃さ |

### Utilities（`Cacarrot/Utilities`）

| 型 | 役割 |
| --- | --- |
| `Theme` | アプリ全体の色（like・nope・superLike・undo・accent）とカードの角丸 |
| `Haptics` | 触覚フィードバック（impact・selection・success） |

## 3. スワイプ判定の仕組み

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Dragging: dragChanged
    Dragging --> Dragging: しきい値を越えたら Haptics.selection
    Dragging --> Idle: dragEnded（しきい値未満）／バネで戻る
    Dragging --> Exiting: dragEnded（しきい値以上）
    Idle --> Exiting: ボタン / VoiceOver アクション
    Exiting --> Idle: 0.28秒後に commit（保存・カードを外す）
```

**しきい値**

| 判定 | 条件 |
| --- | --- |
| like | 横方向 +110pt |
| nope | 横方向 −110pt |
| superLike | 上方向 140pt、かつ縦の移動が横より大きい |

**判定のタイミング**

- 指を離した位置で判定します。
- 届かなかった場合は、勢いを含めた予測位置（`predictedEndTranslation`）でも判定します。そのときのしきい値は 2 倍です。

**アニメーション**

- `withAnimation(_:completionCriteria:completion:)` を使い、カードが画面外へ飛び終わってから保存してデッキから外します。
- 以前は、飛ばしたカードが画面外に残ったままになり、デッキが壊れる不具合がありました。この順番はそれを防ぐためのものです。

**重なりの表示**

- 描画するのは上から 3 枚だけです。
- 一番上のカードを動かすほど、後ろのカードが少しずつ大きく前に出てきます（`CardStackView.dragProgress`）。

## 4. フォルダ構成

```
Cacarrot/
├── Cacarrot.xcodeproj
├── Cacarrot/                 アプリのソース
│   ├── CacarrotApp.swift     エントリポイント・依存の組み立て
│   ├── ContentView.swift     タブ
│   ├── Models/
│   ├── Services/
│   ├── ViewModels/
│   ├── Views/
│   │   ├── Main/             さがす（カード・ボタン・ヘッダー）
│   │   ├── List/             お気に入り
│   │   ├── Profile/          マイページ
│   │   └── Shared/           表紙・ジャンルタグ・詳細シート・プレビュー
│   ├── Utilities/
│   ├── Resources/manga.json  同梱データ（自動生成）
│   └── Assets.xcassets
├── MangaInfoFetcher/         データ取得と変換の Python スクリプト
├── Design/                   ロゴやアイコンの元画像
└── docs/                     このドキュメント
```
