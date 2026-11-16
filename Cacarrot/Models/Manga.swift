//  Manga.swift

import Foundation

/// スワイプカードに表示する作品データ（値型・イミュータブル）
struct Manga: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let title: String
    let author: String
    let genres: [String]
    let summary: String
    /// Assets.xcassets 内の画像名（ローカル画像がある場合）
    let imageName: String?
    /// 表紙画像のURL（リモート画像がある場合）
    let imageURL: URL?

    init(id: Int,
         title: String,
         author: String,
         genres: [String],
         summary: String,
         imageName: String? = nil,
         imageURL: URL? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.genres = genres
        self.summary = summary
        self.imageName = imageName
        self.imageURL = imageURL
    }
}
