//  SwipeHistoryStoreTests.swift

import XCTest
import SwiftData
@testable import Cacarrot

@MainActor
final class SwipeHistoryStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwipeHistoryStore!
    private let items = SampleMangaRepository.items

    override func setUp() async throws {
        container = try ModelContainer(for: SwipeRecord.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = SwipeHistoryStore(context: container.mainContext)
    }

    func testRecordAndSwipedIDs() throws {
        try store.record(items[0], action: .like)
        try store.record(items[1], action: .nope)
        XCTAssertEqual(store.swipedIDs(), [items[0].id, items[1].id])
    }

    func testRecordingSameMangaUpdatesInsteadOfDuplicating() throws {
        try store.record(items[0], action: .nope)
        try store.record(items[0], action: .superLike)
        let records = try container.mainContext.fetch(FetchDescriptor<SwipeRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.action, .superLike)
    }

    func testRemoveAllOfActionKeepsOthers() throws {
        try store.record(items[0], action: .like)
        try store.record(items[1], action: .nope)
        try store.record(items[2], action: .nope)
        try store.removeAll(of: .nope)
        XCTAssertEqual(store.swipedIDs(), [items[0].id])
        try store.removeAll()
        XCTAssertTrue(store.swipedIDs().isEmpty)
    }

    func testRecentHistoryIsNewestFirstAndLimited() async throws {
        for (index, manga) in items.prefix(4).enumerated() {
            try store.record(manga, action: index.isMultiple(of: 2) ? .like : .nope)
            // createdAt の順序が確実に付くよう、少し間を空ける
            try await Task.sleep(for: .milliseconds(5))
        }
        let recent = store.recentHistory(limit: 3)
        XCTAssertEqual(recent.map(\.mangaID), [items[3].id, items[2].id, items[1].id])
        XCTAssertEqual(recent.first?.action, .nope)
    }

    func testLikedPredicateExcludesNope() throws {
        try store.record(items[0], action: .like)
        try store.record(items[1], action: .superLike)
        try store.record(items[2], action: .nope)
        let liked = try container.mainContext.fetch(FetchDescriptor(predicate: SwipeRecord.likedPredicate))
        XCTAssertEqual(Set(liked.map(\.mangaID)), [items[0].id, items[1].id])
    }

    func testUpdateActionKeepsCreatedAt() throws {
        try store.record(items[0], action: .like)
        let before = try container.mainContext.fetch(FetchDescriptor<SwipeRecord>()).first!.createdAt
        try store.updateAction(mangaID: items[0].id, to: .superLike)
        let record = try container.mainContext.fetch(FetchDescriptor<SwipeRecord>()).first!
        XCTAssertEqual(record.action, .superLike)
        XCTAssertEqual(record.createdAt, before, "並び順を保つため日時は変えない")
    }

    func testRefreshSnapshotsUpdatesChangedTitles() throws {
        try store.record(items[0], action: .like)
        try store.record(items[1], action: .nope)
        let renamed = Manga(id: items[0].id, title: "新しいタイトル", author: "新しい作者",
                            genres: ["SF"], summary: "新しいあらすじ",
                            imageURL: URL(string: "https://example.com/a.jpg"),
                            publisher: "出版社", itemURL: URL(string: "https://example.com/item"))
        let updated = try store.refreshSnapshots(with: [renamed, items[1]])
        XCTAssertEqual(updated, 1, "変わっていない作品は数えない")

        let record = try container.mainContext.fetch(
            FetchDescriptor<SwipeRecord>(predicate: #Predicate { $0.mangaID == 0 })).first!
        XCTAssertEqual(record.manga, renamed)
        XCTAssertEqual(record.action, .like, "判定は変えない")
        XCTAssertEqual(try store.refreshSnapshots(with: [renamed]), 0)
    }

    // MARK: - ID の付け替え

    private func newSourceManga(_ id: Int, _ title: String) -> Manga {
        Manga(id: id, title: title, author: "新データの作者", genres: ["少年"], summary: "日本語のあらすじ")
    }

    func testRelinkOrphansByTitle() throws {
        try store.record(items[0], action: .like)          // ONE PIECE（旧ID 0）
        try store.record(items[1], action: .nope)          // DRAGON BALL（旧ID 1）
        let newData = [
            newSourceManga(9784088725093, "ＯＮＥ　ＰＩＥＣＥ"),   // 全角でも同じ作品とみなす
            newSourceManga(9784088518718, "DRAGON BALL"),
            newSourceManga(9784000000001, "新しい作品"),
        ]
        XCTAssertEqual(try store.relinkOrphans(to: newData), 2)
        XCTAssertEqual(store.swipedIDs(), [9784088725093, 9784088518718])

        let onePiece = try container.mainContext.fetch(
            FetchDescriptor<SwipeRecord>(predicate: #Predicate { $0.mangaID == 9784088725093 })).first
        XCTAssertEqual(onePiece?.action, .like, "判定は引き継ぐ")
        XCTAssertEqual(onePiece?.author, "新データの作者", "作品情報も新しいデータにする")
    }

    func testRelinkSkipsAmbiguousAndAlreadySwiped() throws {
        try store.record(items[0], action: .like)                      // ONE PIECE（旧ID 0）
        let duplicate = [newSourceManga(100, "ONE PIECE"), newSourceManga(101, "One Piece")]
        XCTAssertEqual(try store.relinkOrphans(to: duplicate), 0, "同じタイトルが複数あるときは付け替えない")

        let existing = newSourceManga(200, "ONE PIECE")
        try store.record(existing, action: .nope)                      // 新しい ID ですでに判定済み
        XCTAssertEqual(try store.relinkOrphans(to: [existing]), 0, "判定済みの作品とは重ねない")
        XCTAssertEqual(store.swipedIDs(), [items[0].id, 200])
    }

    func testRelinkKeepsKnownRecords() throws {
        try store.record(items[2], action: .like)
        XCTAssertEqual(try store.relinkOrphans(to: Array(items)), 0)
        XCTAssertEqual(store.swipedIDs(), [items[2].id])
    }
}
