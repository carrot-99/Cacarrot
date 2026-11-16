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
        self.actionRawValue = action.rawValue
        self.createdAt = createdAt
    }

    var action: SwipeAction {
        get { SwipeAction(rawValue: actionRawValue) ?? .nope }
        set { actionRawValue = newValue.rawValue }
    }

    var manga: Manga {
        Manga(id: mangaID,
              title: title,
              author: author,
              genres: genres,
              summary: summary,
              imageName: imageName,
              imageURL: imageURLString.flatMap(URL.init(string:)))
    }
}
