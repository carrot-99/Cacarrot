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

    // MARK: - 設定値

    static let horizontalThreshold: CGFloat = 110
    static let verticalThreshold: CGFloat = 140

    // MARK: - 依存

    private let repository: MangaRepository
    private let store: SwipeHistoryStore
    private var allManga: [Manga] = []
    private var history: [(manga: Manga, action: SwipeAction)] = []
    private var pendingAction: SwipeAction?

    init(repository: MangaRepository, store: SwipeHistoryStore) {
        self.repository = repository
        self.store = store
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
            rebuildDeck()
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private func rebuildDeck() {
        let swiped = store.swipedIDs()
        cards = allManga.filter { !swiped.contains($0.id) }
        dragOffset = .zero
        history.removeAll()
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
            swipe(action)
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
    func swipe(_ action: SwipeAction) {
        guard let card = topCard, !isAnimating else { return }
        exitingAction = action
        withAnimation(.easeIn(duration: 0.28), completionCriteria: .logicallyComplete) {
            dragOffset = action.exitOffset(in: cardSize)
        } completion: { [weak self] in
            self?.commit(card, action: action)
        }
    }

    private func commit(_ card: Manga, action: SwipeAction) {
        store.record(card, action: action)
        history.append((card, action))
        action == .superLike ? Haptics.success() : Haptics.impact()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            cards.removeAll { $0.id == card.id }
            dragOffset = .zero
            exitingAction = nil
        }
    }

    /// 直前のスワイプを取り消す
    func undo() {
        guard canUndo, let last = history.popLast() else { return }
        store.remove(mangaID: last.manga.id)
        Haptics.impact(.soft)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            cards.insert(last.manga, at: 0)
            dragOffset = .zero
        }
    }

    /// スキップした作品をデッキに戻す
    func restoreSkipped() {
        store.removeAll(of: .nope)
        withAnimation(.spring) { rebuildDeck() }
    }

    /// すべての履歴を削除して最初からやり直す
    func resetAll() {
        store.removeAll()
        withAnimation(.spring) { rebuildDeck() }
    }

    /// リスト画面から削除された作品をデッキの末尾に戻す
    func forget(mangaID: Int) {
        store.remove(mangaID: mangaID)
        history.removeAll { $0.manga.id == mangaID }
        if let manga = allManga.first(where: { $0.id == mangaID }),
           !cards.contains(where: { $0.id == mangaID }) {
            cards.append(manga)
        }
    }
}
