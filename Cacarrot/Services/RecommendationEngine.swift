//  RecommendationEngine.swift

import Foundation

/// 判定履歴から好みのジャンルを学習し、デッキの並び順を決める
///
/// - いいね +1、スーパーいいね +2、スキップ −0.5 を、その作品の各ジャンルに加算する
/// - 作品のスコア ＝ ジャンルの好み度の平均（−1〜1 に正規化）
/// - 同じジャンルばかりにならないよう、ランダムな揺らぎ（exploration）を加える
/// - さらに discoveryInterval 枚に1枚は、スコアの下半分からランダムに選んだ作品を混ぜる
///   （新しい好みに出会えるように）
struct RecommendationEngine: Sendable {
    /// ランダムの強さ。0 なら完全に好み順、大きいほどシャッフルに近い
    var exploration: Double = 0.6
    /// この枚数ごとに1枚、好みから外れた作品を混ぜる（0 以下で無効）
    var discoveryInterval: Int = 4

    static let weights: [SwipeAction: Double] = [.like: 1, .superLike: 2, .nope: -0.5]

    /// ジャンルごとの好み度（最大の絶対値が 1 になるよう正規化）
    func genreAffinity(from history: [(genres: [String], action: SwipeAction)]) -> [String: Double] {
        var totals: [String: Double] = [:]
        for entry in history {
            let weight = Self.weights[entry.action] ?? 0
            for genre in entry.genres {
                totals[genre, default: 0] += weight
            }
        }
        guard let maxValue = totals.values.map(abs).max(), maxValue > 0 else { return [:] }
        return totals.mapValues { $0 / maxValue }
    }

    /// 作品のスコア（好みのジャンルが多いほど高い）
    func score(_ manga: Manga, affinity: [String: Double]) -> Double {
        guard !manga.genres.isEmpty else { return 0 }
        let sum = manga.genres.reduce(0) { $0 + (affinity[$1] ?? 0) }
        return sum / Double(manga.genres.count)
    }

    /// おすすめ順に並べ替える。履歴がなければ元の順番（ランダム）のまま
    func rank<G: RandomNumberGenerator>(_ items: [Manga],
                                        affinity: [String: Double],
                                        using generator: inout G) -> [Manga] {
        guard !affinity.isEmpty else { return items }
        let noise = max(exploration, .leastNonzeroMagnitude)
        var ranked = items
            .map { ($0, score($0, affinity: affinity) + Double.random(in: 0..<noise, using: &generator)) }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        guard discoveryInterval > 0 else { return ranked }

        var result: [Manga] = []
        result.reserveCapacity(ranked.count)
        while !ranked.isEmpty {
            if (result.count + 1) % discoveryInterval == 0, ranked.count > 1 {
                let index = Int.random(in: (ranked.count / 2)..<ranked.count, using: &generator)
                result.append(ranked.remove(at: index))
            } else {
                result.append(ranked.removeFirst())
            }
        }
        return result
    }

    func rank(_ items: [Manga], affinity: [String: Double]) -> [Manga] {
        var generator = SystemRandomNumberGenerator()
        return rank(items, affinity: affinity, using: &generator)
    }

    // MARK: - 似ている作品

    /// 2作品の近さ（0〜1）。ジャンルの重なり（Jaccard 係数）に、作者が同じなら 0.5 を足して 1 で頭打ち
    static func similarity(_ a: Manga, _ b: Manga) -> Double {
        let lhs = Set(a.genres), rhs = Set(b.genres)
        let union = lhs.union(rhs).count
        let genreScore = union == 0 ? 0 : Double(lhs.intersection(rhs).count) / Double(union)
        let sameAuthor = !a.author.isEmpty && a.author == b.author
        return min(genreScore + (sameAuthor ? 0.5 : 0), 1)
    }

    /// 似ている作品を近い順に返す（同じ近さなら、まだ判定していない作品を先に）
    func similar(to manga: Manga,
                 in candidates: [Manga],
                 checkedIDs: Set<Int> = [],
                 limit: Int = 8) -> [Manga] {
        candidates
            .lazy
            .filter { $0.id != manga.id }
            .map { (manga: $0, score: Self.similarity(manga, $0)) }
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                let lhsChecked = checkedIDs.contains(lhs.manga.id)
                let rhsChecked = checkedIDs.contains(rhs.manga.id)
                if lhsChecked != rhsChecked { return !lhsChecked }
                return lhs.manga.id < rhs.manga.id
            }
            .prefix(limit)
            .map(\.manga)
    }
}
