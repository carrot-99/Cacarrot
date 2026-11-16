//  SaveFailureTests.swift

import XCTest
import SwiftData
@testable import Cacarrot

/// 本物のストアを包み、`failWrites` が true のあいだは書き込みを失敗させる偽物
@MainActor
final class FlakyHistoryStore: SwipeHistoryStoring {
    struct WriteError: LocalizedError {
        var errorDescription: String? { "テスト用の保存エラー" }
    }

    private let base: SwipeHistoryStore
    var failWrites = false

    init(base: SwipeHistoryStore) { self.base = base }

    func swipedIDs() -> Set<Int> { base.swipedIDs() }
    func history() -> [(genres: [String], action: SwipeAction)] { base.history() }
    func recentHistory(limit: Int) -> [(mangaID: Int, action: SwipeAction)] { base.recentHistory(limit: limit) }

    func record(_ manga: Manga, action: SwipeAction) throws {
        if failWrites { throw WriteError() }
        try base.record(manga, action: action)
    }

    func updateAction(mangaID: Int, to action: SwipeAction) throws {
        if failWrites { throw WriteError() }
        try base.updateAction(mangaID: mangaID, to: action)
    }

    func remove(mangaID: Int) throws {
        if failWrites { throw WriteError() }
        try base.remove(mangaID: mangaID)
    }

    func removeAll(of action: SwipeAction?) throws {
        if failWrites { throw WriteError() }
        try base.removeAll(of: action)
    }
}

/// 保存に失敗したときに、画面の状態が壊れず、ユーザーに知らせることを確認する
@MainActor
final class SaveFailureTests: XCTestCase {
    private var container: ModelContainer!
    private var store: FlakyHistoryStore!
    private var analytics: SpyAnalytics!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        container = try ModelContainer(for: SwipeRecord.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = FlakyHistoryStore(base: SwipeHistoryStore(context: container.mainContext))
        analytics = SpyAnalytics()
        suiteName = "CacarrotTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.set(false, forKey: "isRecommendationEnabled")
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeDeck() async -> SwipeDeckViewModel {
        let deck = SwipeDeckViewModel(repository: SampleMangaRepository(), store: store,
                                      defaults: defaults, analytics: analytics)
        await deck.loadIfNeeded()
        return deck
    }

    func testFailedCommitKeepsCardAndShowsError() async {
        let deck = await makeDeck()
        let top = deck.topCard!
        store.failWrites = true

        deck.commit(top, action: .like)

        XCTAssertEqual(deck.topCard?.id, top.id, "保存できなかったカードはデッキに残る")
        XCTAssertEqual(deck.remainingCount, SampleMangaRepository.items.count)
        XCTAssertFalse(deck.isAnimating)
        XCTAssertFalse(deck.canUndo, "保存していない判定は取り消し履歴に入れない")
        XCTAssertNotNil(deck.errorMessage)
        XCTAssertTrue(analytics.events.isEmpty, "失敗した判定はイベントにしない")
        XCTAssertTrue(store.swipedIDs().isEmpty)
    }

    func testFailedUndoKeepsHistory() async {
        let deck = await makeDeck()
        let top = deck.topCard!
        deck.commit(top, action: .like)
        store.failWrites = true

        deck.undo()

        XCTAssertNotEqual(deck.topCard?.id, top.id, "カードは戻らない")
        XCTAssertTrue(deck.canUndo, "あとで取り消せるよう履歴を残す")
        XCTAssertNotNil(deck.errorMessage)

        // 復旧後は取り消せる
        store.failWrites = false
        deck.errorMessage = nil
        deck.undo()
        XCTAssertEqual(deck.topCard?.id, top.id)
        XCTAssertNil(deck.errorMessage)
    }

    func testFailedResetLeavesDeckUnchanged() async {
        let deck = await makeDeck()
        deck.commit(deck.cards[0], action: .nope)
        let before = deck.cards.map(\.id)
        store.failWrites = true

        deck.restoreSkipped()
        XCTAssertEqual(deck.cards.map(\.id), before)
        deck.resetAll()
        XCTAssertEqual(deck.cards.map(\.id), before)
        XCTAssertNotNil(deck.errorMessage)
        XCTAssertEqual(store.swipedIDs().count, 1)
    }

    func testFailedChangeActionAndForget() async throws {
        let deck = await makeDeck()
        let card = deck.cards[0]
        deck.commit(card, action: .like)
        store.failWrites = true

        deck.changeAction(mangaID: card.id, to: .superLike)
        let record = try container.mainContext.fetch(FetchDescriptor<SwipeRecord>()).first
        XCTAssertEqual(record?.action, .like)

        deck.forget(mangaID: card.id)
        XCTAssertFalse(deck.cards.contains { $0.id == card.id }, "削除できなかった作品はデッキに戻さない")
        XCTAssertNotNil(deck.errorMessage)
    }
}
