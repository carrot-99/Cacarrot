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
    /// 出版社
    let publisher: String?
    /// 商品ページのURL（楽天ブックスなど）
    let itemURL: URL?

    init(id: Int,
         title: String,
         author: String,
         genres: [String],
         summary: String,
         imageName: String? = nil,
         imageURL: URL? = nil,
         publisher: String? = nil,
         itemURL: URL? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.genres = genres
        self.summary = summary
        self.imageName = imageName
        self.imageURL = imageURL
        self.publisher = publisher
        self.itemURL = itemURL
    }
}
