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
}
