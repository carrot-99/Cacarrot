//  SwipeDeckViewModel.swift

import SwiftUI
import Observation

/// スワイプデッキの状態とロジックを管理する
@Observable
@MainActor
final class SwipeDeckViewModel {

    enum LoadState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    // MARK: - 公開状態

    /// 残りのカード（先頭が一番上）
    private(set) var cards: [Manga] = []
    /// 一番上のカードのドラッグ量
    var dragOffset: CGSize = .zero
    /// カードの表示サイズ（ボタン操作時の退場アニメーションに使用）
    var cardSize: CGSize = CGSize(width: 360, height: 560)
    private(set) var loadState: LoadState = .idle
    /// 退場アニメーション中のアクション
    private(set) var exitingAction: SwipeAction?

    var topCard: Manga? { cards.first }
    var isAnimating: Bool { exitingAction != nil }
    var canUndo: Bool { !history.isEmpty && !isAnimating }
    var remainingCount: Int { cards.count }
    var totalCount: Int { allManga.count }
    /// 判定済みの作品数（絞り込みに関係なく、全作品のうち）
    var checkedCount: Int { allManga.lazy.filter { self.swipedIDs.contains($0.id) }.count }
    /// 絞り込み条件に合う作品数（判定済みを含む）
    var filteredTotalCount: Int { allManga.lazy.filter { self.matchesFilter($0) }.count }
    /// 楽天ブックスのデータを使っているか（クレジット表記の切り替えに使う）
    var usesRakutenData: Bool { allManga.contains { $0.itemURL != nil } }
    /// 保存に失敗したときのメッセージ（表示したら nil に戻す）
    var errorMessage: String?
    /// 「視差効果を減らす」設定。オンなら、カードを画面外へ飛ばさずにその場で入れ替える
    var reduceMotion = false

    // MARK: - 設定値

    static let horizontalThreshold: CGFloat = 110
    static let verticalThreshold: CGFloat = 140
    /// 表紙を先読みする枚数（表示中の3枚＋この先）
    static let prefetchCount = 6
    /// この枚数を判定するごとに、残りのカードを好みに合わせて並べ直す
    static let rerankInterval = 10
    /// 並べ直しても動かさない上のカード枚数（見えているカードが入れ替わらないように）
    static let stableTopCount = 3
    /// 取り消せる判定の最大数（再起動後も保存済みの履歴から復元する）
    static let undoLimit = 20

    // MARK: - おすすめ順

    /// 好みのジャンルに近い作品を先に出す（オフならランダム順）
    var isRecommendationEnabled: Bool {
        didSet {
            guard isRecommendationEnabled != oldValue else { return }
            defaults.set(isRecommendationEnabled, forKey: Self.recommendationKey)
            analytics.log(.setRecommendation(enabled: isRecommendationEnabled))
            withAnimation(.spring) { reorderRemaining() }
        }
    }

    private static let recommendationKey = "isRecommendationEnabled"

    // MARK: - ジャンルの絞り込み

    /// 選択中のジャンル（空なら絞り込みなし。いずれかのジャンルを含む作品を表示）
    private(set) var selectedGenres: Set<String> = []
    /// 絞り込みに使えるジャンルと作品数（作品数の多い順）
    private(set) var availableGenres: [(name: String, count: Int)] = []
    var isFiltering: Bool { !selectedGenres.isEmpty }

    private static let genreFilterKey = "selectedGenres"

    /// 絞り込みを変更してデッキを作り直す（取り消し履歴は残す）
    func setGenreFilter(_ genres: Set<String>) {
        guard genres != selectedGenres else { return }
        selectedGenres = genres
        defaults.set(Array(genres).sorted(), forKey: Self.genreFilterKey)
        analytics.log(.applyGenreFilter(genreCount: genres.count))
        withAnimation(.spring) { rebuildDeck(resetHistory: false) }
    }

    private func matchesFilter(_ manga: Manga) -> Bool {
        selectedGenres.isEmpty || manga.genres.contains(where: selectedGenres.contains)
    }

    private func updateAvailableGenres() {
        var counts: [String: Int] = [:]
        for manga in allManga {
            for genre in manga.genres { counts[genre, default: 0] += 1 }
        }
        availableGenres = counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { (name: $0.key, count: $0.value) }
        // データ更新で存在しなくなったジャンルは選択から外す
        selectedGenres = selectedGenres.filter { counts[$0] != nil }
    }

    // MARK: - 依存

    private let repository: MangaRepository
    private let store: any SwipeHistoryStoring
    private let recommender: RecommendationEngine
    private let imageLoader: ImageLoader
    private let defaults: UserDefaults
    private let analytics: AnalyticsLogging
    private var allManga: [Manga] = []
    private var history: [(manga: Manga, action: SwipeAction)] = []
    private var pendingAction: SwipeAction?
    private var swipesSinceRerank = 0
    /// 判定済みの作品ID（SwiftData への問い合わせを減らすためのキャッシュ）
    private var swipedIDs: Set<Int> = []

    init(repository: MangaRepository,
         store: any SwipeHistoryStoring,
         recommender: RecommendationEngine = RecommendationEngine(),
         imageLoader: ImageLoader = .shared,
         defaults: UserDefaults = .standard,
         analytics: AnalyticsLogging = NoopAnalyticsLogger()) {
        self.repository = repository
        self.analytics = analytics
        self.store = store
        self.recommender = recommender
        self.imageLoader = imageLoader
        self.defaults = defaults
        self.isRecommendationEnabled = defaults.object(forKey: Self.recommendationKey) as? Bool ?? true
        self.selectedGenres = Set(defaults.stringArray(forKey: Self.genreFilterKey) ?? [])
    }

    // MARK: - 読み込み

    func loadIfNeeded() async {
        guard loadState == .idle else { return }
        await reload()
    }

    func reload() async {
        loadState = .loading
        do {
            allManga = try await repository.fetchAll()
            updateAvailableGenres()
            rebuildDeck()
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private func rebuildDeck(resetHistory: Bool = true) {
        swipedIDs = store.swipedIDs()
        let remaining = allManga.filter { !swipedIDs.contains($0.id) && matchesFilter($0) }
        cards = isRecommendationEnabled
            ? recommender.rank(remaining, affinity: currentAffinity())
            : remaining
        dragOffset = .zero
        if resetHistory { restoreUndoHistory() }
        swipesSinceRerank = 0
        prefetchUpcoming()
    }

    /// 保存済みの判定から取り消し履歴を作り直す（アプリを再起動しても取り消せるように）
    private func restoreUndoHistory() {
        let mangaByID = Dictionary(allManga.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        history = store.recentHistory(limit: Self.undoLimit)
            .reversed()  // 古い順に並べ、末尾が直前の判定になるようにする
            .compactMap { entry in mangaByID[entry.mangaID].map { ($0, entry.action) } }
    }

    private func report(_ error: Error) {
        errorMessage = "履歴を保存できませんでした。もう一度お試しください。\n（\(error.localizedDescription)）"
        Haptics.error()
    }

    // MARK: - 並び順・先読み

    private func currentAffinity() -> [String: Double] {
        recommender.genreAffinity(from: store.history())
    }

    /// 見えている上のカードはそのままに、残りを並べ直す
    private func reorderRemaining() {
        guard cards.count > Self.stableTopCount else { return }
        let top = Array(cards.prefix(Self.stableTopCount))
        let rest = Array(cards.dropFirst(Self.stableTopCount))
        let reordered = isRecommendationEnabled
            ? recommender.rank(rest, affinity: currentAffinity())
            : rest.shuffled()
        cards = top + reordered
        swipesSinceRerank = 0
        prefetchUpcoming()
    }

    private func prefetchUpcoming() {
        imageLoader.prefetch(cards.prefix(Self.prefetchCount).compactMap(\.imageURL))
    }

    // MARK: - ドラッグ

    func dragChanged(_ translation: CGSize) {
        guard !isAnimating else { return }
        dragOffset = translation
        let action = Self.action(for: translation)
        if action != pendingAction {
            pendingAction = action
            if action != nil { Haptics.selection() }
        }
    }

    func dragEnded(translation: CGSize, predicted: CGSize) {
        guard !isAnimating else { return }
        pendingAction = nil
        // 指を離した位置、または勢い（予測位置）でしきい値を超えたら確定
        if let action = Self.action(for: translation) ?? Self.action(for: predicted, scale: 2) {
            swipe(action, source: .gesture)
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                dragOffset = .zero
            }
        }
    }

    /// ドラッグ量から判定を求める
    static func action(for offset: CGSize, scale: CGFloat = 1) -> SwipeAction? {
        if -offset.height > verticalThreshold * scale, abs(offset.height) > abs(offset.width) {
            return .superLike
        }
        if offset.width > horizontalThreshold * scale { return .like }
        if offset.width < -horizontalThreshold * scale { return .nope }
        return nil
    }

    /// GOOD / NOPE / SUPER スタンプの表示濃度
    func stampOpacity(for action: SwipeAction) -> Double {
        if let exitingAction { return exitingAction == action ? 1 : 0 }
        let dx = dragOffset.width, dy = dragOffset.height
        switch action {
        case .like: return dx > 0 && abs(dx) >= abs(dy) ? min(dx / Self.horizontalThreshold, 1) : 0
        case .nope: return dx < 0 && abs(dx) >= abs(dy) ? min(-dx / Self.horizontalThreshold, 1) : 0
        case .superLike: return dy < 0 && abs(dy) > abs(dx) ? min(-dy / Self.verticalThreshold, 1) : 0
        }
    }

    // MARK: - アクション

    /// カードを判定して画面外へ飛ばす（ボタン・ドラッグ共通）
    func swipe(_ action: SwipeAction, source: SwipeSource = .button) {
        guard let card = topCard, !isAnimating else { return }
        if reduceMotion {
            commit(card, action: action, source: source)
            return
        }
        exitingAction = action
        withAnimation(.easeIn(duration: 0.28), completionCriteria: .logicallyComplete) {
            dragOffset = action.exitOffset(in: cardSize)
        } completion: { [weak self] in
            self?.commit(card, action: action, source: source)
        }
    }

    /// 画面側の操作を記録する（詳細を開いた、など）
    func track(_ event: AnalyticsEvent) {
        analytics.log(event)
    }

    /// 判定を保存してデッキから外す（アニメーション完了後に呼ばれる。テストから直接呼ぶため internal）
    func commit(_ card: Manga, action: SwipeAction, source: SwipeSource = .button) {
        do {
            try store.record(card, action: action)
        } catch {
            // 保存できなかったカードは元の位置に戻す
            report(error)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                dragOffset = .zero
                exitingAction = nil
            }
            return
        }
        swipedIDs.insert(card.id)
        history.append((card, action))
        analytics.log(.swipe(action: action, source: source))
        action == .superLike ? Haptics.success() : Haptics.impact()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8)) {
            cards.removeAll { $0.id == card.id }
            dragOffset = .zero
            exitingAction = nil
        }
        if cards.isEmpty { analytics.log(.deckFinished) }
        swipesSinceRerank += 1
        if isRecommendationEnabled, swipesSinceRerank >= Self.rerankInterval {
            reorderRemaining()  // 見えていないカードだけを並べ直すのでアニメーション不要
        } else {
            prefetchUpcoming()
        }
    }

    /// 直前のスワイプを取り消す
    func undo() {
        guard canUndo, let last = history.popLast() else { return }
        do {
            try store.remove(mangaID: last.manga.id)
        } catch {
            history.append(last)
            report(error)
            return
        }
        swipedIDs.remove(last.manga.id)
        analytics.log(.undo)
        Haptics.impact(.soft)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            cards.insert(last.manga, at: 0)
            dragOffset = .zero
        }
    }

    /// スキップした作品をデッキに戻す
    func restoreSkipped() {
        do {
            try store.removeAll(of: .nope)
        } catch {
            report(error)
            return
        }
        withAnimation(.spring) { rebuildDeck() }
    }

    /// すべての履歴を削除して最初からやり直す
    func resetAll() {
        do {
            try store.removeAll()
        } catch {
            report(error)
            return
        }
        withAnimation(.spring) { rebuildDeck() }
    }

    /// お気に入りの判定を変更する（いいね ⇄ スーパーいいね）
    func changeAction(mangaID: Int, to action: SwipeAction) {
        do {
            try store.updateAction(mangaID: mangaID, to: action)
        } catch {
            report(error)
            return
        }
        // 取り消し履歴も新しい判定に合わせる
        if let index = history.firstIndex(where: { $0.manga.id == mangaID }) {
            history[index].action = action
        }
        Haptics.selection()
    }

    /// リスト画面から削除された作品をデッキの末尾に戻す
    func forget(mangaID: Int) {
        do {
            try store.remove(mangaID: mangaID)
        } catch {
            report(error)
            return
        }
        swipedIDs.remove(mangaID)
        history.removeAll { $0.manga.id == mangaID }
        if let manga = allManga.first(where: { $0.id == mangaID }),
           matchesFilter(manga),
           !cards.contains(where: { $0.id == mangaID }) {
            cards.append(manga)
        }
    }
}
