//  SwipeRecord.swift

import Foundation
import SwiftData

/// スワイプ履歴（SwiftDataで永続化）
@Model
final class SwipeRecord {
    @Attribute(.unique) var mangaID: Int
    var title: String
    var author: String
    var genres: [String]
    var summary: String
    var imageName: String?
    var imageURLString: String?
    var publisher: String?
    var itemURLString: String?
    var actionRawValue: String
    var createdAt: Date

    init(manga: Manga, action: SwipeAction, createdAt: Date = .now) {
        self.mangaID = manga.id
        self.title = manga.title
        self.author = manga.author
        self.genres = manga.genres
        self.summary = manga.summary
        self.imageName = manga.imageName
        self.imageURLString = manga.imageURL?.absoluteString
        self.publisher = manga.publisher
        self.itemURLString = manga.itemURL?.absoluteString
        self.actionRawValue = action.rawValue
        self.createdAt = createdAt
    }

    var action: SwipeAction {
        get { SwipeAction(rawValue: actionRawValue) ?? .nope }
        set { actionRawValue = newValue.rawValue }
    }

    /// 最新の作品データで、保存しているコピーを更新する（変更があれば true）
    @discardableResult
    func refresh(from manga: Manga) -> Bool {
        let imageURL = manga.imageURL?.absoluteString
        let itemURL = manga.itemURL?.absoluteString
        guard title != manga.title || author != manga.author || genres != manga.genres
                || summary != manga.summary || imageName != manga.imageName
                || imageURLString != imageURL || publisher != manga.publisher
                || itemURLString != itemURL else { return false }
        title = manga.title
        author = manga.author
        genres = manga.genres
        summary = manga.summary
        imageName = manga.imageName
        imageURLString = imageURL
        publisher = manga.publisher
        itemURLString = itemURL
        return true
    }

    var manga: Manga {
        Manga(id: mangaID,
              title: title,
              author: author,
              genres: genres,
              summary: summary,
              imageName: imageName,
              imageURL: imageURLString.flatMap(URL.init(string:)),
              publisher: publisher,
              itemURL: itemURLString.flatMap(URL.init(string:)))
    }
}

extension SwipeRecord {
    /// いいね・スーパーいいねした履歴（#Predicate の中では enum を直接使えないため rawValue で比較する）
    static var likedPredicate: Predicate<SwipeRecord> {
        let nope = SwipeAction.nope.rawValue
        return #Predicate { $0.actionRawValue != nope }
    }

    /// スキップした履歴
    static var skippedPredicate: Predicate<SwipeRecord> {
        let nope = SwipeAction.nope.rawValue
        return #Predicate { $0.actionRawValue == nope }
    }
}

/// マイページの集計（判定ごとの件数と、好きなジャンル）
///
/// 履歴を1回だけ走査して求める。画面の再描画のたびに何度も全件を数えないようにするため
struct SwipeStats: Equatable {
    private(set) var counts: [SwipeAction: Int] = [:]
    /// いいね +1、スーパーいいね +2 で数えたジャンルの上位（多い順。同数は名前順）
    private(set) var topGenres: [(genre: String, count: Int)] = []

    static let topGenreLimit = 5

    init<S: Sequence>(records: S) where S.Element == SwipeRecord {
        var genreCounts: [String: Int] = [:]
        for record in records {
            let action = record.action
            counts[action, default: 0] += 1
            guard action != .nope else { continue }
            let weight = action == .superLike ? 2 : 1
            for genre in record.genres { genreCounts[genre, default: 0] += weight }
        }
        topGenres = genreCounts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(Self.topGenreLimit)
            .map { (genre: $0.key, count: $0.value) }
    }

    func count(_ action: SwipeAction) -> Int { counts[action] ?? 0 }

    static func == (lhs: SwipeStats, rhs: SwipeStats) -> Bool {
        lhs.counts == rhs.counts
            && lhs.topGenres.map(\.genre) == rhs.topGenres.map(\.genre)
            && lhs.topGenres.map(\.count) == rhs.topGenres.map(\.count)
    }
}
