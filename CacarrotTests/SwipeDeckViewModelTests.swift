//  SwipeDeckViewModelTests.swift

import XCTest
import SwiftData
@testable import Cacarrot

@MainActor
final class SwipeDeckViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwipeHistoryStore!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private let items = SampleMangaRepository.items

    override func setUp() async throws {
        container = try ModelContainer(for: SwipeRecord.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = SwipeHistoryStore(context: container.mainContext)
        suiteName = "CacarrotTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// サンプル6件を、元の順番のまま読み込んだデッキ
    private func makeDeck(recommendation: Bool = false) async -> SwipeDeckViewModel {
        defaults.set(recommendation, forKey: "isRecommendationEnabled")
        let deck = SwipeDeckViewModel(repository: SampleMangaRepository(), store: store, defaults: defaults)
        await deck.loadIfNeeded()
        return deck
    }

    // MARK: - スワイプ判定

    func testSwipeThresholds() {
        XCTAssertEqual(SwipeDeckViewModel.action(for: CGSize(width: 120, height: 0)), .like)
        XCTAssertEqual(SwipeDeckViewModel.action(for: CGSize(width: -120, height: 10)), .nope)
        XCTAssertEqual(SwipeDeckViewModel.action(for: CGSize(width: 20, height: -150)), .superLike)
        XCTAssertNil(SwipeDeckViewModel.action(for: CGSize(width: 100, height: 0)))
        // 上方向でも横の移動が大きければスーパーいいねにしない
        XCTAssertEqual(SwipeDeckViewModel.action(for: CGSize(width: 200, height: -150)), .like)
        // 勢い（予測位置）はしきい値を2倍にして判定する
        XCTAssertNil(SwipeDeckViewModel.action(for: CGSize(width: 200, height: 0), scale: 2))
    }

    // MARK: - 読み込み・判定・取り消し

    func testLoadExcludesAlreadySwiped() async throws {
        try store.record(items[0], action: .like)
        let deck = await makeDeck()
        XCTAssertEqual(deck.loadState, .loaded)
        XCTAssertEqual(deck.remainingCount, items.count - 1)
        XCTAssertFalse(deck.cards.contains { $0.id == items[0].id })
        XCTAssertEqual(deck.checkedCount, 1)
    }

    func testCommitRemovesCardAndSaves() async {
        let deck = await makeDeck()
        let top = deck.topCard!
        deck.commit(top, action: .like)
        XCTAssertEqual(deck.remainingCount, items.count - 1)
        XCTAssertNotEqual(deck.topCard?.id, top.id)
        XCTAssertTrue(store.swipedIDs().contains(top.id))
        XCTAssertTrue(deck.canUndo)
    }

    func testUndoRestoresCardOnTop() async {
        let deck = await makeDeck()
        let top = deck.topCard!
        deck.commit(top, action: .nope)
        deck.undo()
        XCTAssertEqual(deck.topCard?.id, top.id)
        XCTAssertFalse(store.swipedIDs().contains(top.id))
        XCTAssertFalse(deck.canUndo)
    }

    func testUndoHistorySurvivesRelaunch() async throws {
        let first = await makeDeck()
        let a = first.cards[0], b = first.cards[1]
        first.commit(a, action: .like)
        try await Task.sleep(for: .milliseconds(5))
        first.commit(b, action: .nope)

        // 同じ保存先で ViewModel を作り直す（＝アプリの再起動）
        let relaunched = await makeDeck()
        XCTAssertTrue(relaunched.canUndo)
        relaunched.undo()
        XCTAssertEqual(relaunched.topCard?.id, b.id, "直前の判定（b）から取り消される")
        relaunched.undo()
        XCTAssertEqual(relaunched.topCard?.id, a.id)
        XCTAssertFalse(relaunched.canUndo)
    }

    func testRestoreSkippedAndResetAll() async {
        let deck = await makeDeck()
        deck.commit(deck.cards[0], action: .nope)
        deck.commit(deck.cards[0], action: .like)
        XCTAssertEqual(deck.remainingCount, items.count - 2)

        deck.restoreSkipped()
        XCTAssertEqual(deck.remainingCount, items.count - 1, "スキップだけが戻る")

        deck.resetAll()
        XCTAssertEqual(deck.remainingCount, items.count)
        XCTAssertFalse(deck.canUndo)
    }

    func testForgetPutsCardBackAtEnd() async {
        let deck = await makeDeck()
        let liked = deck.cards[0]
        deck.commit(liked, action: .like)
        deck.forget(mangaID: liked.id)
        XCTAssertEqual(deck.cards.last?.id, liked.id)
        XCTAssertFalse(store.swipedIDs().contains(liked.id))
    }

    // MARK: - 絞り込み

    func testGenreFilter() async {
        let deck = await makeDeck()
        deck.setGenreFilter(["ギャグ"])
        XCTAssertTrue(deck.isFiltering)
        XCTAssertEqual(deck.cards.map(\.title), ["ボボボーボ・ボーボボ"])
        XCTAssertEqual(deck.filteredTotalCount, 1)
        XCTAssertEqual(defaults.stringArray(forKey: "selectedGenres"), ["ギャグ"], "選択は保存される")

        deck.setGenreFilter([])
        XCTAssertEqual(deck.remainingCount, items.count)
    }

    func testGenreFilterKeepsUndoHistory() async {
        let deck = await makeDeck()
        deck.commit(deck.cards[0], action: .like)
        deck.setGenreFilter(["ファンタジー"])
        XCTAssertTrue(deck.canUndo)
    }

    func testAvailableGenresSortedByCount() async {
        let deck = await makeDeck()
        // サンプル: ファンタジー4件、バトル3件、冒険2件、ギャグ1件
        XCTAssertEqual(deck.availableGenres.first?.name, "ファンタジー")
        XCTAssertEqual(deck.availableGenres.first?.count, 4)
        XCTAssertEqual(deck.availableGenres.map(\.name), ["ファンタジー", "バトル", "冒険", "ギャグ"])
    }

    // MARK: - おすすめ順

    func testRecommendationSettingIsPersisted() async {
        let deck = await makeDeck(recommendation: true)
        deck.isRecommendationEnabled = false
        XCTAssertEqual(defaults.object(forKey: "isRecommendationEnabled") as? Bool, false)
    }

    func testWithoutRecommendationKeepsRepositoryOrder() async {
        let deck = await makeDeck(recommendation: false)
        XCTAssertEqual(deck.cards.map(\.id), items.map(\.id))
    }

    // MARK: - お気に入りの編集

    func testChangeActionUpdatesStoreAndUndo() async throws {
        let deck = await makeDeck()
        let card = deck.cards[0]
        deck.commit(card, action: .like)
        deck.changeAction(mangaID: card.id, to: .superLike)

        let record = try container.mainContext.fetch(FetchDescriptor<SwipeRecord>()).first
        XCTAssertEqual(record?.action, .superLike)
        XCTAssertNil(deck.errorMessage)

        // 取り消すと、カードがデッキに戻り履歴も消える
        deck.undo()
        XCTAssertEqual(deck.topCard?.id, card.id)
        XCTAssertTrue(store.swipedIDs().isEmpty)
    }
}
