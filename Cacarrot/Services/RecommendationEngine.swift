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
}
