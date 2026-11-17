//  RecommendationEngineTests.swift

import XCTest
@testable import Cacarrot

/// 再現性のある乱数（テスト用）
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class RecommendationEngineTests: XCTestCase {
    private let engine = RecommendationEngine()

    private func manga(_ id: Int, _ genres: [String]) -> Manga {
        Manga(id: id, title: "\(id)", author: "", genres: genres, summary: "")
    }

    func testAffinityWeightsAndNormalization() {
        let affinity = engine.genreAffinity(from: [
            (["恋愛", "日常"], .superLike),
            (["恋愛"], .like),
            (["ホラー"], .nope),
            (["ホラー", "アクション"], .nope),
        ])
        XCTAssertEqual(affinity["恋愛"], 1)                       // 2 + 1 = 3 が最大 → 1
        XCTAssertEqual(affinity["日常"] ?? 0, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertLessThan(affinity["ホラー"] ?? 0, 0)              // スキップはマイナス
    }

    func testEmptyHistoryKeepsOriginalOrder() {
        let items = (0..<10).map { manga($0, ["恋愛"]) }
        XCTAssertTrue(engine.genreAffinity(from: []).isEmpty)
        XCTAssertEqual(engine.rank(items, affinity: [:]).map(\.id), items.map(\.id))
    }

    func testPreferredGenreComesFirstWithDiscoverySlots() {
        let items = (0..<100).map { manga($0, $0.isMultiple(of: 2) ? ["恋愛"] : ["ホラー"]) }
        let affinity = ["恋愛": 1.0, "ホラー": -0.5]
        var generator = SeededGenerator(seed: 42)
        let top20 = engine.rank(items, affinity: affinity, using: &generator).prefix(20)
        // 4枚に1枚（5枠）は好みから外れた作品を混ぜる
        XCTAssertEqual(top20.filter { $0.genres == ["恋愛"] }.count, 15)
    }

    func testDiscoveryCanBeDisabled() {
        let items = (0..<100).map { manga($0, $0.isMultiple(of: 2) ? ["恋愛"] : ["ホラー"]) }
        let noDiscovery = RecommendationEngine(exploration: 0.6, discoveryInterval: 0)
        var generator = SeededGenerator(seed: 1)
        let ranked = noDiscovery.rank(items, affinity: ["恋愛": 1, "ホラー": -0.5], using: &generator)
        XCTAssertTrue(ranked.prefix(50).allSatisfy { $0.genres == ["恋愛"] })
    }

    func testRankingKeepsEveryItemOnce() {
        let items = (0..<57).map { manga($0, [$0.isMultiple(of: 3) ? "SF" : "日常"]) }
        var generator = SeededGenerator(seed: 3)
        let ranked = engine.rank(items, affinity: ["SF": 1], using: &generator)
        XCTAssertEqual(ranked.count, items.count)
        XCTAssertEqual(Set(ranked.map(\.id)), Set(items.map(\.id)))
    }

    // MARK: - 似ている作品

    private func manga(_ id: Int, _ genres: [String], author: String = "") -> Manga {
        Manga(id: id, title: "T\(id)", author: author, genres: genres, summary: "")
    }

    func testSimilarityUsesGenreOverlapAndAuthor() {
        let base = manga(1, ["バトル", "冒険"], author: "作者A")
        XCTAssertEqual(RecommendationEngine.similarity(base, manga(2, ["バトル", "冒険"])), 1)
        XCTAssertEqual(RecommendationEngine.similarity(base, manga(3, ["バトル", "恋愛"])), 1.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(RecommendationEngine.similarity(base, manga(4, ["恋愛"])), 0)
        XCTAssertEqual(RecommendationEngine.similarity(base, manga(5, ["恋愛"], author: "作者A")), 0.5,
                       "ジャンルが違っても作者が同じなら近い")
        XCTAssertEqual(RecommendationEngine.similarity(manga(6, []), manga(7, [])), 0, "作者が空なら一致とみなさない")
    }

    func testSimilarSortsByScoreThenUncheckedAndExcludesSelf() {
        let base = manga(1, ["バトル", "冒険"])
        let candidates = [
            base,
            manga(2, ["バトル"]),           // 0.5
            manga(3, ["バトル", "冒険"]),   // 1.0
            manga(4, ["冒険"]),             // 0.5
            manga(5, ["恋愛"]),             // 0 → 出さない
        ]
        let result = RecommendationEngine().similar(to: base, in: candidates, checkedIDs: [2])
        XCTAssertEqual(result.map(\.id), [3, 4, 2], "同じ近さなら判定していない作品を先に")
        XCTAssertEqual(RecommendationEngine().similar(to: base, in: candidates, limit: 1).map(\.id), [3])
    }
}
